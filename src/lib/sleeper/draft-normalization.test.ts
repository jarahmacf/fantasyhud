import { describe, expect, it } from "vitest"
import {
  normalizeDraftDetail,
  normalizeDraftList,
  normalizeDraftBoard,
  resolveDraftParticipation,
} from "./draft-normalization"

export const draftFixture = () => ({
  draft_id: "draft-a",
  league_id: "league-a",
  sport: "nfl",
  season: "2026",
  season_type: "regular",
  type: "snake",
  status: "complete",
  settings: { teams: 2, rounds: 1 },
  metadata: { name: " Test " },
  draft_order: { user_a: 1, user_b: 2 },
  slot_to_roster_id: { "1": 1, "2": 2 },
  start_time: 1_780_000_000_000,
})
export const picksFixture = () =>
  [1, 2].map((n) => ({
    draft_id: "draft-a",
    player_id: String(n),
    pick_no: n,
    round: 1,
    draft_slot: n,
    picked_by: n === 1 ? "user_a" : "user_b",
    roster_id: String(n),
    is_keeper: null,
    metadata: {
      player_id: String(n),
      position: "RB",
      team: "BUF",
      first_name: "Example",
      last_name: String(n),
    },
  }))
const board = () =>
  normalizeDraftBoard(
    normalizeDraftDetail(draftFixture(), 2026),
    picksFixture()
  )

describe("Sleeper complete draft normalization", () => {
  it("retains a complete shared board and nullable keeper truth", () => {
    const result = board()
    expect(result.complete).toBe(true)
    expect(result.picks).toHaveLength(2)
    expect(result.containsKeeperPicks).toBeNull()
    expect(result.picks[0]!.isKeeper).toBeNull()
    expect(result.detail.name).toBe("Test")
    expect(result.detail.draftPoolType).toBe("unknown")
  })
  it.each([null, {}, [null], [draftFixture(), draftFixture()]])(
    "rejects invalid list %j",
    (value) => expect(() => normalizeDraftList(value, 2026)).toThrow()
  )
  it.each([
    { season: "2025" },
    { sport: "nba" },
    { draft_id: 123 },
    { draft_id: " draft-a" },
    { draft_order: { user_a: 3 } },
    { slot_to_roster_id: { "01": 1 } },
    { settings: { teams: null, rounds: -1 } },
  ])("rejects invalid detail %j", (patch) =>
    expect(() =>
      normalizeDraftDetail({ ...draftFixture(), ...patch }, 2026)
    ).toThrow()
  )
  it.each([
    { draft_id: "wrong" },
    { player_id: "0" },
    { player_id: 1 },
    { is_keeper: 0 },
    { round: 0 },
    { draft_slot: 3 },
    { metadata: { player_id: "wrong" } },
    { roster_id: "01" },
  ])("rejects invalid pick %j", (patch) => {
    const picks = picksFixture()
    Object.assign(picks[0]!, patch)
    expect(() =>
      normalizeDraftBoard(normalizeDraftDetail(draftFixture(), 2026), picks)
    ).toThrow()
  })
  it("rejects gaps, duplicate picks and duplicate player identities", () => {
    for (const picks of [
      [picksFixture()[1]],
      [picksFixture()[0], picksFixture()[0]],
      [
        picksFixture()[0],
        { ...picksFixture()[1], player_id: "1", metadata: { player_id: "1" } },
      ],
    ])
      expect(() =>
        normalizeDraftBoard(normalizeDraftDetail(draftFixture(), 2026), picks)
      ).toThrow()
  })
  it("does not finalize truncated or dimensionless completed sources", () => {
    expect(
      normalizeDraftBoard(normalizeDraftDetail(draftFixture(), 2026), [
        picksFixture()[0],
      ]).complete
    ).toBe(false)
    expect(
      normalizeDraftBoard(
        normalizeDraftDetail({ ...draftFixture(), settings: {} }, 2026),
        picksFixture()
      ).complete
    ).toBe(false)
  })
  it("does not turn a drafting board into a finalized one", () =>
    expect(
      normalizeDraftBoard(
        normalizeDraftDetail({ ...draftFixture(), status: "drafting" }, 2026),
        picksFixture()
      ).complete
    ).toBe(false))
  it("preserves absent maps separately from explicit empty maps", () => {
    expect(
      normalizeDraftDetail({ ...draftFixture(), draft_order: null }, 2026)
        .draftOrder
    ).toBeNull()
    expect(
      normalizeDraftDetail({ ...draftFixture(), draft_order: {} }, 2026)
        .draftOrder
    ).toEqual({})
  })
  it("does not infer auction prices from pick numbers or unreviewed fields", () => {
    const result = normalizeDraftBoard(
      normalizeDraftDetail(
        {
          ...draftFixture(),
          type: "auction",
          settings: { teams: 2, rounds: 1, budget: 200 },
        },
        2026
      ),
      picksFixture().map((p) => ({ ...p, amount: 25 }))
    )
    expect(result.picks[0]!.auctionAmount).toBeNull()
    expect(result.detail.settings.budget).toBe(200)
  })
  it("confirms one consistent seat and preserves unknown evidence", () => {
    expect(resolveDraftParticipation(board(), "user_a", true, 1)).toEqual({
      status: "confirmed",
      draftSlot: 1,
    })
    expect(
      resolveDraftParticipation(board(), "unknown", true, null).status
    ).toBe("unresolved")
    expect(
      resolveDraftParticipation(board(), "unknown", false, null).status
    ).toBe("not_participant")
    expect(
      resolveDraftParticipation(board(), "user_a", false, null).status
    ).toBe("unresolved")
  })
  it("fails closed on multiple account seats", () =>
    expect(() =>
      resolveDraftParticipation(board(), "user_a", true, 2)
    ).toThrow())
  it("permits co-managed seats with deterministic exact user order", () => {
    const detail = normalizeDraftDetail(
      { ...draftFixture(), draft_order: { z: 1, user_a: 1, user_b: 2 } },
      2026
    )
    expect(
      normalizeDraftBoard(detail, picksFixture()).slots[0]!.sourceUserIds
    ).toEqual(["user_a", "z"])
  })
})
