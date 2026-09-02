import { describe, expect, it } from "vitest"

import {
  normalizeSleeperRosterLeagueBundle,
  sleeperRosterStarterPlaceholder,
  validateCompleteRosterBundleCollection,
} from "./roster-normalization"

const fetchedAt = "2026-09-01T20:30:00.000Z"

const ordinaryUser = {
  user_id: "account-owner",
  league_id: "league-one",
  display_name: "  Fixture Owner  ",
  avatar: "avatar-id",
  metadata: { team_name: "  Team One  ", untouched: { value: true } },
  is_owner: true,
}

const ordinaryRoster = {
  league_id: "league-one",
  roster_id: 1,
  owner_id: "account-owner",
  co_owners: [],
  players: ["player-a", "player-b", "player-c"],
  starters: ["player-a", "0", "player-b"],
  reserve: ["player-c"],
  taxi: ["player-b"],
  keepers: ["player-a"],
  settings: { wins: 1 },
  metadata: { record: "1-0" },
}

function normalize(
  users: unknown = [ordinaryUser],
  rosters: unknown = [ordinaryRoster],
  rosterPositions: readonly string[] = ["QB", "RB", "WR", "BN"]
) {
  return normalizeSleeperRosterLeagueBundle({
    externalLeagueId: "league-one",
    leagueSeason: 2026,
    rosterPositions,
    bundleFetchedAt: fetchedAt,
    users,
    rosters,
    sourceMetadata: {
      users_response_bytes: 100,
      rosters_response_bytes: 200,
    },
  })
}

describe("normalizeSleeperRosterLeagueBundle", () => {
  it("normalizes users while retaining source metadata and commissioner state", () => {
    const user = normalize().users[0]!
    expect(user).toMatchObject({
      externalUserId: "account-owner",
      username: null,
      displayName: "Fixture Owner",
      teamName: "Team One",
      avatarId: "avatar-id",
      avatarUrl: "https://sleepercdn.com/avatars/avatar-id",
      isCommissioner: true,
    })
    expect(user.metadata).toMatchObject({
      ...ordinaryUser.metadata,
      _fantasyhud: {
        metadata_source_state: "object",
        is_owner_source_state: "boolean",
        normalization_warning_fields: [],
      },
    })
  })

  it("turns malformed optional display data into null with bounded categories", () => {
    const bundle = normalize([
      {
        ...ordinaryUser,
        username: "bad\nname",
        display_name: 42,
        is_owner: "true",
        metadata: null,
      },
    ])
    expect(bundle.users[0]).toMatchObject({
      username: null,
      displayName: null,
      isCommissioner: false,
      metadata: {
        _fantasyhud: {
          metadata_source_state: "null",
          is_owner_source_state: "malformed",
          normalization_warning_fields: [
            "display_name",
            "is_owner",
            "username",
          ],
        },
      },
    })
    expect(bundle.sourceMetadata.normalization_warning_fields).toEqual([
      "display_name",
      "is_owner",
      "username",
    ])
  })

  it("retains absent optional-source state without inventing values", () => {
    const user = normalize([
      {
        user_id: "account-owner",
        league_id: "league-one",
        display_name: "Fixture Owner",
      },
    ]).users[0]!
    expect(user).toMatchObject({
      username: null,
      teamName: null,
      avatarId: null,
      isCommissioner: false,
      metadata: {
        _fantasyhud: {
          metadata_source_state: "absent",
          is_owner_source_state: "absent",
          normalization_warning_fields: [],
        },
      },
    })
  })

  it("requires the league user's exact source league identity", () => {
    expect(normalize().users[0]?.externalUserId).toBe("account-owner")

    expect(() => normalize([{ user_id: "account-owner" }])).toThrow()
    expect(() => normalize([{ ...ordinaryUser, league_id: null }])).toThrow()
    expect(() =>
      normalize([{ ...ordinaryUser, league_id: "other-league" }])
    ).toThrow()
    expect(() =>
      normalize([{ ...ordinaryUser, league_id: " league-one " }])
    ).toThrow()
    expect(() =>
      normalize([{ ...ordinaryUser, league_id: "league\none" }])
    ).toThrow()
  })

  it("preserves exact avatar identifiers and rejects display normalization", () => {
    expect(normalize().users[0]?.avatarId).toBe("avatar-id")
    expect(
      normalize([{ user_id: "account-owner", league_id: "league-one" }])
        .users[0]?.avatarId
    ).toBeNull()
    expect(
      normalize([{ ...ordinaryUser, avatar: null }]).users[0]?.avatarId
    ).toBeNull()
    expect(() =>
      normalize([{ ...ordinaryUser, avatar: " avatar-id " }])
    ).toThrow()
    expect(() =>
      normalize([{ ...ordinaryUser, avatar: "avatar\nid" }])
    ).toThrow()
    expect(() => normalize([{ ...ordinaryUser, avatar: "" }])).toThrow()
    expect(() => normalize([{ ...ordinaryUser, avatar: 42 }])).toThrow()
  })

  it("preserves exact arrays and derives membership order, slots, and keeper flags", () => {
    const roster = normalize().rosters[0]!
    expect(roster.sourceStarterIds).toEqual(["player-a", "0", "player-b"])
    expect(roster.memberships).toEqual([
      expect.objectContaining({
        externalPlayerId: "player-a",
        sourceOrder: 1,
        isStarter: true,
        starterOrder: 1,
        starterSlot: "QB",
        isReserve: false,
        isTaxi: false,
        isKeeper: true,
      }),
      expect.objectContaining({
        externalPlayerId: "player-b",
        sourceOrder: 2,
        isStarter: true,
        starterOrder: 3,
        starterSlot: "WR",
        isTaxi: true,
      }),
      expect.objectContaining({
        externalPlayerId: "player-c",
        sourceOrder: 3,
        isStarter: false,
        starterOrder: null,
        starterSlot: null,
        isReserve: true,
      }),
    ])
    expect(
      roster.memberships?.some(
        (membership) =>
          membership.externalPlayerId === sleeperRosterStarterPlaceholder
      )
    ).toBe(false)
  })

  it("preserves null arrays as unknown and does not fabricate memberships", () => {
    const roster = normalize(
      [ordinaryUser],
      [
        {
          ...ordinaryRoster,
          co_owners: null,
          players: null,
          starters: null,
          reserve: null,
          taxi: null,
          keepers: null,
        },
      ]
    ).rosters[0]!

    expect(roster).toMatchObject({
      coOwnerExternalUserIds: null,
      sourcePlayerIds: null,
      sourceStarterIds: null,
      sourceReserveIds: null,
      sourceTaxiIds: null,
      sourceKeeperIds: null,
      memberships: null,
    })
  })

  it("preserves explicit empty arrays as confirmed empty", () => {
    const roster = normalize(
      [ordinaryUser],
      [
        {
          ...ordinaryRoster,
          co_owners: [],
          players: [],
          starters: [],
          reserve: [],
          taxi: [],
          keepers: [],
        },
      ]
    ).rosters[0]!
    expect(roster.sourcePlayerIds).toEqual([])
    expect(roster.memberships).toEqual([])
  })

  it("marks null annotation state so SQL can preserve prior facts", () => {
    const membership = normalize(
      [ordinaryUser],
      [
        {
          ...ordinaryRoster,
          starters: null,
          reserve: null,
          taxi: null,
          keepers: null,
        },
      ]
    ).rosters[0]!.memberships?.[0]
    expect(membership?.sourceMetadata.annotation_source_state).toEqual({
      starters: "unknown",
      reserve: "unknown",
      taxi: "unknown",
      keepers: "unknown",
    })
  })

  it("retains a valid unknown exact player reference as membership input", () => {
    const roster = normalize(
      [ordinaryUser],
      [
        {
          ...ordinaryRoster,
          players: ["roster-unknown-0001"],
          starters: [],
          reserve: [],
          taxi: [],
          keepers: [],
        },
      ]
    ).rosters[0]!
    expect(roster.memberships?.[0]?.externalPlayerId).toBe(
      "roster-unknown-0001"
    )
  })

  it("fails closed on an unexplained starter outside players", () => {
    expect(() =>
      normalize(
        [ordinaryUser],
        [{ ...ordinaryRoster, starters: ["unexpected-player"] }]
      )
    ).toThrow()
  })

  it.each([
    [{ ...ordinaryRoster, players: ["player-a", "player-a"] }],
    [{ ...ordinaryRoster, players: ["0"], starters: ["0"] }],
    [{ ...ordinaryRoster, starters: ["player-a", "player-a"] }],
    [{ ...ordinaryRoster, reserve: ["not-in-players"] }],
    [{ ...ordinaryRoster, roster_id: Number.MAX_SAFE_INTEGER }],
    [{ ...ordinaryRoster, league_id: "other-league" }],
    [{ ...ordinaryRoster, settings: null }],
  ])("rejects malformed roster identity or membership state", (rosters) => {
    expect(() => normalize([ordinaryUser], rosters)).toThrow()
  })

  it("rejects duplicate user and roster identities", () => {
    expect(() => normalize([ordinaryUser, ordinaryUser])).toThrow()
    expect(() =>
      normalize([ordinaryUser], [ordinaryRoster, ordinaryRoster])
    ).toThrow()
  })

  it("preserves exact bundle ordering and validates the frozen set", () => {
    const first = normalize()
    const second = normalizeSleeperRosterLeagueBundle({
      ...{
        externalLeagueId: "league-two",
        leagueSeason: 2026,
        rosterPositions: ["QB"],
        bundleFetchedAt: fetchedAt,
        users: [],
        rosters: [],
        sourceMetadata: {},
      },
    })

    expect(
      validateCompleteRosterBundleCollection(
        [second, first],
        ["league-one", "league-two"],
        2026
      ).map((bundle) => bundle.externalLeagueId)
    ).toEqual(["league-one", "league-two"])
    expect(() =>
      validateCompleteRosterBundleCollection(
        [first],
        ["league-one", "league-two"],
        2026
      )
    ).toThrow()
  })
})
