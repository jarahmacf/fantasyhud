import { beforeEach, describe, expect, it, vi } from "vitest"

vi.mock("next/cache", () => ({ revalidatePath: vi.fn() }))
vi.mock("@/lib/auth/current-user", () => ({
  requireAuthIdentity: vi.fn(),
}))
vi.mock("@/lib/sleeper/roster-collection.server", () => ({
  fetchNormalizedSleeperRosterBundles: vi.fn(),
}))
vi.mock("@/lib/supabase/admin", () => ({
  createAdminSupabaseClient: vi.fn(),
}))
vi.mock("@/lib/supabase/server", () => ({
  createServerSupabaseClient: vi.fn(),
}))

import { revalidatePath } from "next/cache"

import { importCurrentSleeperRostersAction } from "./actions"
import { requireAuthIdentity } from "@/lib/auth/current-user"
import { fetchNormalizedSleeperRosterBundles } from "@/lib/sleeper/roster-collection.server"
import type { NormalizedRosterLeagueBundle } from "@/lib/sleeper/roster-types"
import { SleeperClientError } from "@/lib/sleeper/types"
import { createAdminSupabaseClient } from "@/lib/supabase/admin"
import { createServerSupabaseClient } from "@/lib/supabase/server"

const mockedIdentity = vi.mocked(requireAuthIdentity)
const mockedFetch = vi.mocked(fetchNormalizedSleeperRosterBundles)
const mockedAdmin = vi.mocked(createAdminSupabaseClient)
const mockedServer = vi.mocked(createServerSupabaseClient)
const mockedRevalidate = vi.mocked(revalidatePath)
const idle = { status: "idle" as const, message: null }

type QueryResult = { data: unknown; error: null }

function queryBuilder(result: QueryResult) {
  const builder: Record<string, unknown> = {}
  for (const method of ["select", "eq", "is", "in", "limit", "order"]) {
    builder[method] = vi.fn(() => builder)
  }
  builder.maybeSingle = vi.fn(async () => result)
  builder.then = (
    resolve: (value: QueryResult) => unknown,
    reject: (reason: unknown) => unknown
  ) => Promise.resolve(result).then(resolve, reject)
  return builder
}

function configurePrerequisites(options: { catalog?: boolean } = {}) {
  const results = new Map<string, QueryResult[]>([
    [
      "user_fantasy_accounts",
      [
        {
          data: {
            fantasy_account_id: "account-id",
            fantasy_accounts: {
              id: "account-id",
              provider: "sleeper",
              external_user_id: "account-owner",
            },
          },
          error: null,
        },
      ],
    ],
    [
      "provider_season_states",
      [{ data: { league_season: 2026 }, error: null }],
    ],
    [
      "fantasy_account_leagues",
      [
        {
          data: [
            {
              league_id: "league-db-b",
              leagues: {
                external_league_id: "league-b",
                provider: "sleeper",
                sport: "nfl",
                season: 2026,
              },
            },
          ],
          error: null,
        },
        {
          data: [
            {
              league_id: "league-db-b",
              leagues: {
                external_league_id: "league-b",
                roster_positions: ["QB", "BN"],
                provider: "sleeper",
                sport: "nfl",
                season: 2026,
              },
            },
            {
              league_id: "league-db-a",
              leagues: {
                external_league_id: "league-a",
                roster_positions: ["QB", "BN"],
                provider: "sleeper",
                sport: "nfl",
                season: 2026,
              },
            },
          ],
          error: null,
        },
      ],
    ],
    [
      "provider_catalog_runs",
      [
        {
          data: options.catalog === false ? null : { id: "catalog-run" },
          error: null,
        },
      ],
    ],
  ])

  mockedServer.mockResolvedValue({
    from: vi.fn((table: string) => {
      const result = results.get(table)?.shift()
      if (!result) throw new Error(`Unexpected query for ${table}`)
      return queryBuilder(result)
    }),
  } as never)
}

function bundle(externalLeagueId: string): NormalizedRosterLeagueBundle {
  return {
    externalLeagueId,
    leagueSeason: 2026,
    bundleFetchedAt: "2026-09-01T20:30:00.000Z",
    users: [
      {
        externalUserId: "account-owner",
        username: null,
        displayName: "Fixture Owner",
        teamName: "Fixture Team",
        avatarId: null,
        avatarUrl: null,
        isCommissioner: false,
        metadata: { _fantasyhud: { is_owner_source_state: "null" } },
      },
    ],
    rosters: [
      {
        externalRosterId: 1,
        ownerExternalUserId: "account-owner",
        coOwnerExternalUserIds: null,
        sourcePlayerIds: null,
        sourceStarterIds: null,
        sourceReserveIds: null,
        sourceTaxiIds: null,
        sourceKeeperIds: null,
        settings: {},
        metadata: {},
        memberships: null,
      },
    ],
    sourceMetadata: { users_response_bytes: 100 },
  }
}

beforeEach(() => {
  vi.clearAllMocks()
  mockedIdentity.mockResolvedValue({
    id: "user-id",
    email: "user@example.test",
  })
  configurePrerequisites()
})

describe("importCurrentSleeperRostersAction", () => {
  it("reuses a running import without making source requests", async () => {
    const rpc = vi.fn().mockResolvedValue({
      data: [
        {
          sync_run_id: "running-run",
          created_run: false,
          reused_run: true,
          recovered_stale_run: false,
          league_season: 2026,
          expected_external_league_ids: ["league-a", "league-b"],
        },
      ],
      error: null,
    })
    mockedAdmin.mockReturnValue({ rpc } as never)

    await expect(
      importCurrentSleeperRostersAction(idle, new FormData())
    ).resolves.toEqual({
      status: "running",
      message: "Roster import is already running.",
    })
    expect(mockedFetch).not.toHaveBeenCalled()
    expect(rpc).toHaveBeenCalledTimes(1)
    expect(mockedRevalidate).toHaveBeenCalledWith("/")
    expect(mockedRevalidate).toHaveBeenCalledWith("/rosters")
  })

  it("collects the frozen scope, stages exact bundles in order, and completes", async () => {
    mockedFetch.mockResolvedValue([bundle("league-b"), bundle("league-a")])
    const rpc = vi.fn(
      async (functionName: string, args: Record<string, unknown>) => {
        void args
        if (functionName === "start_sleeper_roster_sync") {
          return {
            data: [
              {
                sync_run_id: "new-run",
                created_run: true,
                reused_run: false,
                recovered_stale_run: false,
                league_season: 2026,
                expected_external_league_ids: ["league-a", "league-b"],
              },
            ],
            error: null,
          }
        }
        if (functionName === "stage_sleeper_roster_league_bundle") {
          return {
            data: [
              {
                sync_run_id: "new-run",
                staged_leagues: 1,
                progress_total: 2,
                replayed_bundle: false,
              },
            ],
            error: null,
          }
        }
        if (functionName === "complete_sleeper_roster_sync") {
          return {
            data: [
              {
                final_status: "succeeded",
                active_owned_rosters: 2,
                active_owned_memberships: 15,
              },
            ],
            error: null,
          }
        }
        return { data: null, error: { message: "unexpected" } }
      }
    )
    mockedAdmin.mockReturnValue({ rpc } as never)

    await expect(
      importCurrentSleeperRostersAction(idle, new FormData())
    ).resolves.toEqual({
      status: "success",
      message: "Roster import complete.",
      activeOwnedRosters: 2,
      activeOwnedMemberships: 15,
    })

    expect(mockedFetch).toHaveBeenCalledWith(
      [
        { externalLeagueId: "league-a", rosterPositions: ["QB", "BN"] },
        { externalLeagueId: "league-b", rosterPositions: ["QB", "BN"] },
      ],
      2026
    )
    const stages = rpc.mock.calls.filter(
      ([functionName]) => functionName === "stage_sleeper_roster_league_bundle"
    )
    expect(stages).toHaveLength(2)
    expect(
      stages.map(
        ([, args]) =>
          (args as { p_external_league_id: string }).p_external_league_id
      )
    ).toEqual(["league-a", "league-b"])
    expect(
      (stages[0]?.[1] as { p_bundle: { rosters: unknown[] } }).p_bundle
        .rosters[0]
    ).toMatchObject({
      source_player_ids: null,
      memberships: null,
    })
  })

  it("fails the private run and returns a safe source error", async () => {
    mockedFetch.mockRejectedValue(new SleeperClientError("timeout"))
    const rpc = vi.fn(async (functionName: string) => {
      if (functionName === "start_sleeper_roster_sync") {
        return {
          data: [
            {
              sync_run_id: "failed-run",
              created_run: true,
              reused_run: false,
              recovered_stale_run: false,
              league_season: 2026,
              expected_external_league_ids: ["league-a", "league-b"],
            },
          ],
          error: null,
        }
      }
      return {
        data: [{ sync_run_id: "failed-run", status: "failed" }],
        error: null,
      }
    })
    mockedAdmin.mockReturnValue({ rpc } as never)

    await expect(
      importCurrentSleeperRostersAction(idle, new FormData())
    ).resolves.toEqual({
      status: "error",
      message: "Sleeper is temporarily unavailable. Try again.",
    })
    expect(rpc).toHaveBeenCalledWith("fail_sleeper_roster_sync", {
      p_user_id: "user-id",
      p_fantasy_account_id: "account-id",
      p_sync_run_id: "failed-run",
      p_error_code: "source_unavailable",
      p_error_message: "Sleeper is temporarily unavailable. Try again.",
      p_retryable: true,
    })
  })

  it("requires a published player catalog before starting", async () => {
    configurePrerequisites({ catalog: false })
    mockedAdmin.mockReturnValue({ rpc: vi.fn() } as never)

    await expect(
      importCurrentSleeperRostersAction(idle, new FormData())
    ).resolves.toEqual({
      status: "error",
      message: "Import the player catalog first.",
    })
    expect(mockedAdmin).not.toHaveBeenCalled()
    expect(mockedFetch).not.toHaveBeenCalled()
  })
})
