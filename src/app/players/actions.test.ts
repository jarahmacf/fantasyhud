import { beforeEach, describe, expect, it, vi } from "vitest"

vi.mock("next/cache", () => ({ revalidatePath: vi.fn() }))
vi.mock("@/lib/auth/current-user", () => ({
  requireAuthIdentity: vi.fn(),
}))
vi.mock("@/lib/sleeper/player-catalog.server", () => ({
  fetchSleeperPlayerCatalog: vi.fn(),
}))
vi.mock("@/lib/supabase/admin", () => ({
  createAdminSupabaseClient: vi.fn(),
}))
vi.mock("@/lib/supabase/server", () => ({
  createServerSupabaseClient: vi.fn(),
}))

import { refreshSleeperPlayerCatalogAction } from "./actions"
import { requireAuthIdentity } from "@/lib/auth/current-user"
import { fetchSleeperPlayerCatalog } from "@/lib/sleeper/player-catalog.server"
import type { NormalizedSleeperPlayerRecord } from "@/lib/sleeper/player-types"
import { SleeperClientError } from "@/lib/sleeper/types"
import { createAdminSupabaseClient } from "@/lib/supabase/admin"
import { createServerSupabaseClient } from "@/lib/supabase/server"

const mockedIdentity = vi.mocked(requireAuthIdentity)
const mockedFetch = vi.mocked(fetchSleeperPlayerCatalog)
const mockedAdmin = vi.mocked(createAdminSupabaseClient)
const mockedServer = vi.mocked(createServerSupabaseClient)
const idle = { status: "idle" as const, message: null }

function normalizedRecord(index: number): NormalizedSleeperPlayerRecord {
  const id = `player-${index.toString().padStart(4, "0")}`
  return {
    sleeperPlayerId: id,
    profile: {
      sport: "nfl",
      entityType: "player",
      displayName: `Player ${index}`,
      firstName: "Player",
      lastName: String(index),
      fullName: `Player ${index}`,
      primaryPosition: "WR",
      fantasyPositions: ["WR"],
      nflTeam: "SEA",
      active: true,
      status: "Active",
      jerseyNumber: 10,
      age: 25,
      height: "6-1",
      weight: "205",
      yearsExperience: 3,
      college: null,
      highSchool: null,
      birthCountry: null,
      depthChartPosition: null,
      depthChartOrder: null,
      injuryStatus: null,
      injuryBodyPart: null,
      injuryStartDate: null,
      practiceParticipation: null,
      newsUpdatedAt: null,
      searchRank: index,
      profileSource: "sleeper",
      sourceMetadata: {
        unmodeled_fields: {},
        normalization_warning_fields: [],
      },
      profileFetchedAt: "2026-08-31T12:00:00.000Z",
    },
    externalIds: [],
    normalizationWarningCount: 0,
  }
}

function configureConnectedAccount() {
  const builder = {
    select: vi.fn(),
    eq: vi.fn(),
    limit: vi.fn(),
    maybeSingle: vi.fn().mockResolvedValue({
      data: { fantasy_accounts: { provider: "sleeper" } },
      error: null,
    }),
  }
  builder.select.mockReturnValue(builder)
  builder.eq.mockReturnValue(builder)
  builder.limit.mockReturnValue(builder)
  mockedServer.mockResolvedValue({
    from: vi.fn().mockReturnValue(builder),
  } as never)
}

beforeEach(() => {
  vi.clearAllMocks()
  mockedIdentity.mockResolvedValue({
    id: "user-id",
    email: "user@example.test",
  })
  configureConnectedAccount()
})

describe("refreshSleeperPlayerCatalogAction", () => {
  it("returns a fresh global catalog without a Sleeper request", async () => {
    const rpc = vi.fn().mockResolvedValue({
      data: [
        {
          catalog_run_id: "successful-run",
          created_run: false,
          reused_run: false,
          catalog_fresh: true,
          recovered_stale_run: false,
          last_success_at: "2026-08-31T12:00:00.000Z",
        },
      ],
      error: null,
    })
    mockedAdmin.mockReturnValue({ rpc } as never)

    const result = await refreshSleeperPlayerCatalogAction(idle, new FormData())

    expect(result).toEqual({
      status: "success",
      message: "Player catalog is current.",
    })
    expect(mockedFetch).not.toHaveBeenCalled()
    expect(rpc).toHaveBeenCalledTimes(1)
  })

  it("stages a new full catalog sequentially in deterministic 500-record batches", async () => {
    const records = Array.from({ length: 600 }, (_, index) =>
      normalizedRecord(index)
    ).reverse()
    mockedFetch.mockResolvedValue({
      records,
      sourceFetchedAt: "2026-08-31T12:00:00.000Z",
      sourceBytes: 100_000,
      sourceRecordCount: 600,
    })
    const rpc = vi.fn(
      async (functionName: string, args: Record<string, unknown>) => {
        if (functionName === "start_sleeper_player_catalog_sync") {
          return {
            data: [
              {
                catalog_run_id: "new-run",
                created_run: true,
                reused_run: false,
                catalog_fresh: false,
                recovered_stale_run: false,
                last_success_at: null,
              },
            ],
            error: null,
          }
        }
        if (functionName === "stage_sleeper_player_catalog_batch") {
          return {
            data: [
              {
                catalog_run_id: "new-run",
                staged_records: (args.p_records as unknown[]).length,
                total_staged_records: 600,
                progress_total: 600,
                replayed_batch: false,
              },
            ],
            error: null,
          }
        }
        if (functionName === "complete_sleeper_player_catalog_sync") {
          return { data: [{ observed_records: 600 }], error: null }
        }
        return { data: null, error: { message: "unexpected" } }
      }
    )
    mockedAdmin.mockReturnValue({ rpc } as never)

    const result = await refreshSleeperPlayerCatalogAction(idle, new FormData())

    expect(result).toEqual({
      status: "success",
      message: "Player catalog refreshed.",
      observedRecords: 600,
    })
    const stages = rpc.mock.calls.filter(
      ([functionName]) => functionName === "stage_sleeper_player_catalog_batch"
    )
    expect(stages).toHaveLength(2)
    expect((stages[0]?.[1] as { p_records: unknown[] }).p_records).toHaveLength(
      500
    )
    expect((stages[1]?.[1] as { p_records: unknown[] }).p_records).toHaveLength(
      100
    )
    expect(
      (stages[0]?.[1] as { p_records: { external_player_id: string }[] })
        .p_records[0]?.external_player_id
    ).toBe("player-0000")
  })

  it("fails the private run and returns a safe source message", async () => {
    mockedFetch.mockRejectedValue(new SleeperClientError("timeout"))
    const rpc = vi.fn(async (functionName: string) => {
      if (functionName === "start_sleeper_player_catalog_sync") {
        return {
          data: [
            {
              catalog_run_id: "failed-run",
              created_run: true,
              reused_run: false,
              catalog_fresh: false,
            },
          ],
          error: null,
        }
      }
      return { data: [{ status: "failed", changed_run: true }], error: null }
    })
    mockedAdmin.mockReturnValue({ rpc } as never)

    const result = await refreshSleeperPlayerCatalogAction(idle, new FormData())

    expect(result).toEqual({
      status: "error",
      message: "Sleeper is temporarily unavailable. Try again.",
    })
    expect(rpc).toHaveBeenCalledWith("fail_sleeper_player_catalog_sync", {
      p_user_id: "user-id",
      p_catalog_run_id: "failed-run",
      p_error_code: "source_unavailable",
      p_error_message: "Sleeper is temporarily unavailable. Try again.",
      p_retryable: true,
    })
  })
})
