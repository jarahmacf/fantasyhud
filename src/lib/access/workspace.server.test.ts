import { beforeEach, describe, expect, it, vi } from "vitest"

vi.mock("server-only", () => ({}))
vi.mock("./temporary-workspace.server", () => ({
  getTemporaryWorkspace: vi.fn(),
}))
vi.mock("@/lib/auth/current-user", () => ({ getCurrentAuthIdentity: vi.fn() }))
vi.mock("@/lib/supabase/server", () => ({
  createServerSupabaseClient: vi.fn(),
}))

import { getCurrentAuthIdentity } from "@/lib/auth/current-user"
import { createServerSupabaseClient } from "@/lib/supabase/server"
import { getTemporaryWorkspace } from "./temporary-workspace.server"
import { getWorkspaceAccess } from "./workspace.server"

describe("workspace selection", () => {
  beforeEach(() => vi.resetAllMocks())

  it("opens only the configured workspace without reading cookies or identifying a user", async () => {
    const supabase = { from: vi.fn() }
    const account = {
      id: "selected",
      provider: "sleeper",
      username: "fixture",
      display_name: "Fixture",
    }
    vi.mocked(getTemporaryWorkspace).mockResolvedValue({
      account,
      supabase,
    } as never)
    const access = await getWorkspaceAccess()
    expect(access?.account).toEqual(account)
    expect(access?.readOnly).toBe(true)
    expect(access?.identity).toEqual({
      email: null,
      accountLabel: "@fixture",
      accessMode: "temporary",
    })
    expect(getCurrentAuthIdentity).not.toHaveBeenCalled()
    expect(createServerSupabaseClient).not.toHaveBeenCalled()
    expect(supabase.from).not.toHaveBeenCalled()
  })

  it("requires a real user when temporary access is disabled", async () => {
    vi.mocked(getTemporaryWorkspace).mockResolvedValue(null)
    vi.mocked(getCurrentAuthIdentity).mockResolvedValue(null)
    expect(await getWorkspaceAccess()).toBeNull()
    expect(createServerSupabaseClient).not.toHaveBeenCalled()
  })
})
