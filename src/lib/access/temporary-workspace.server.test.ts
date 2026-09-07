import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"

vi.mock("server-only", () => ({}))
vi.mock("@supabase/supabase-js", () => ({ createClient: vi.fn() }))
vi.mock("@/lib/supabase/env", () => ({
  getPublicSupabaseEnvironment: () => ({
    url: "http://127.0.0.1:54321",
    publishableKey: "public-test-key",
  }),
}))

import { createClient } from "@supabase/supabase-js"
import { getTemporaryWorkspace } from "./temporary-workspace.server"

const rpc = vi.fn()

describe("temporary workspace access", () => {
  beforeEach(() => {
    vi.stubEnv("FANTASYHUD_TEMPORARY_ACCESS", "on")
    vi.mocked(createClient)
      .mockReset()
      .mockReturnValue({ rpc } as never)
    rpc.mockReset()
  })
  afterEach(() => vi.stubEnv("FANTASYHUD_TEMPORARY_ACCESS", "off"))

  it("can be disabled without creating a database client", async () => {
    vi.stubEnv("FANTASYHUD_TEMPORARY_ACCESS", "off")
    expect(await getTemporaryWorkspace()).toBeNull()
    expect(createClient).not.toHaveBeenCalled()
  })

  it("uses only the public key with all session persistence disabled", async () => {
    const account = {
      id: "account",
      provider: "sleeper",
      username: "fixture",
      display_name: null,
    }
    rpc.mockResolvedValue({ data: [account], error: null })
    expect((await getTemporaryWorkspace())?.account).toEqual(account)
    expect(createClient).toHaveBeenCalledWith(
      "http://127.0.0.1:54321",
      "public-test-key",
      {
        auth: {
          persistSession: false,
          autoRefreshToken: false,
          detectSessionInUrl: false,
        },
      }
    )
    expect(rpc).toHaveBeenCalledWith("get_temporary_workspace")
  })

  it("returns to normal authentication when the database switch is off", async () => {
    rpc.mockResolvedValue({ data: [], error: null })
    expect(await getTemporaryWorkspace()).toBeNull()
  })

  it("tolerates an older schema during integration deployment", async () => {
    rpc.mockResolvedValue({ data: null, error: { code: "PGRST202" } })
    expect(await getTemporaryWorkspace()).toBeNull()
  })

  it("does not expose raw database failures or pretend an outage is disabled access", async () => {
    rpc.mockResolvedValue({
      data: null,
      error: { code: "42501", message: "private database detail" },
    })
    await expect(getTemporaryWorkspace()).rejects.toThrow(
      "Unable to load workspace access settings."
    )
  })
})
