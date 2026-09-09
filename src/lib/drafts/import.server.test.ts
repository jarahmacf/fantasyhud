import { beforeEach, describe, expect, it, vi } from "vitest"
vi.mock("server-only", () => ({}))
vi.mock("@/lib/auth/current-user", () => ({ requireAuthIdentity: vi.fn() }))
vi.mock("@/lib/supabase/admin", () => ({ createAdminSupabaseClient: vi.fn() }))
vi.mock("@/lib/supabase/server", () => ({
  createServerSupabaseClient: vi.fn(),
}))
vi.mock("@/lib/sleeper/draft-collection.server", () => ({
  fetchNormalizedSleeperDraftCollection: vi.fn(),
}))
import { requireAuthIdentity } from "@/lib/auth/current-user"
import { createAdminSupabaseClient } from "@/lib/supabase/admin"
import { createServerSupabaseClient } from "@/lib/supabase/server"
import { fetchNormalizedSleeperDraftCollection } from "@/lib/sleeper/draft-collection.server"
import { importPrimaryAccountDrafts } from "./import.server"
const rpc = vi.fn()
const account = vi.fn()
beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(requireAuthIdentity).mockResolvedValue({
    id: "verified-user",
    email: null,
  })
  const query = {
    select: vi.fn().mockReturnThis(),
    eq: vi.fn().mockReturnThis(),
    maybeSingle: account,
  }
  vi.mocked(createServerSupabaseClient).mockResolvedValue({
    from: () => query,
  } as unknown as Awaited<ReturnType<typeof createServerSupabaseClient>>)
  account.mockResolvedValue({
    data: { fantasy_accounts: { id: "tracked-account", provider: "sleeper" } },
    error: null,
  })
  vi.mocked(createAdminSupabaseClient).mockReturnValue({
    rpc,
  } as unknown as ReturnType<typeof createAdminSupabaseClient>)
  rpc.mockImplementation(async (name) => ({
    error: null,
    data:
      name === "start_sleeper_draft_sync"
        ? {
            runId: "run-a",
            reused: false,
            externalUserId: "canonical-sleeper",
            season: 2026,
            externalLeagueIds: ["league-a"],
          }
        : name === "complete_sleeper_draft_sync"
          ? {
              drafts: 0,
              confirmedParticipations: 0,
              unresolvedParticipations: 0,
            }
          : null,
  }))
  vi.mocked(fetchNormalizedSleeperDraftCollection).mockResolvedValue({
    version: "sleeper-draft-collection/v1",
    scope: {
      externalUserId: "canonical-sleeper",
      season: 2026,
      externalLeagueIds: ["league-a"],
    },
    userCollection: {
      externalDraftIds: [],
      sourceFetchedAt: "2026-09-09T12:00:00Z",
      responseBytes: 2,
    },
    leagueCollections: [],
    drafts: [],
  })
})
describe("authorized server draft orchestration", () => {
  it("constructs no admin client when temporary access blocks writes", async () => {
    vi.mocked(requireAuthIdentity).mockRejectedValue(new Error("read only"))
    await expect(importPrimaryAccountDrafts()).rejects.toThrow("read only")
    expect(createAdminSupabaseClient).not.toHaveBeenCalled()
    expect(fetchNormalizedSleeperDraftCollection).not.toHaveBeenCalled()
  })
  it("constructs no admin client without a tracked primary account", async () => {
    account.mockResolvedValue({ data: null, error: null })
    expect((await importPrimaryAccountDrafts()).status).toBe("error")
    expect(createAdminSupabaseClient).not.toHaveBeenCalled()
  })
  it("reuses running work without provider requests", async () => {
    rpc.mockResolvedValue({
      data: { reused: true, runId: "existing" },
      error: null,
    })
    expect((await importPrimaryAccountDrafts()).status).toBe("running")
    expect(fetchNormalizedSleeperDraftCollection).not.toHaveBeenCalled()
  })
  it("uses only the database-frozen provider identity and season", async () => {
    expect((await importPrimaryAccountDrafts()).status).toBe("success")
    expect(fetchNormalizedSleeperDraftCollection).toHaveBeenCalledWith(
      {
        externalUserId: "canonical-sleeper",
        season: 2026,
        externalLeagueIds: ["league-a"],
      },
      expect.objectContaining({ heartbeat: expect.any(Function) })
    )
    expect(rpc.mock.calls.map(([name]) => name)).toEqual([
      "start_sleeper_draft_sync",
      "stage_sleeper_draft_source",
      "complete_sleeper_draft_sync",
    ])
  })
  it("fails the attempt without publication on source failure", async () => {
    vi.mocked(fetchNormalizedSleeperDraftCollection).mockRejectedValue(
      new Error("untrusted source detail")
    )
    const result = await importPrimaryAccountDrafts()
    expect(result.status).toBe("error")
    expect(result.message).not.toContain("untrusted")
    expect(rpc.mock.calls.map(([name]) => name)).toEqual([
      "start_sleeper_draft_sync",
      "fail_sleeper_draft_sync",
    ])
  })
})
