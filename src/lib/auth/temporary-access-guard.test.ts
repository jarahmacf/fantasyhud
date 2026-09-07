import { beforeEach, describe, expect, it, vi } from "vitest"

vi.mock("server-only", () => ({}))
vi.mock("next/navigation", () => ({
  redirect: vi.fn(() => {
    throw new Error("redirect:/")
  }),
}))
vi.mock("next/cache", () => ({ revalidatePath: vi.fn() }))
vi.mock("@/lib/access/temporary-workspace.server", () => ({
  getTemporaryWorkspace: vi.fn(),
}))
vi.mock("@/lib/supabase/server", () => ({
  createServerSupabaseClient: vi.fn(),
}))

import { getTemporaryWorkspace } from "@/lib/access/temporary-workspace.server"
import { createServerSupabaseClient } from "@/lib/supabase/server"
import {
  forgotPasswordAction,
  signInAction,
  signOutAction,
  signUpAction,
  updatePasswordAction,
} from "@/app/auth/actions"
import { requireAuthIdentity } from "./current-user"

describe("temporary access mutation guards", () => {
  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(getTemporaryWorkspace).mockResolvedValue({
      account: { id: "configured" },
    } as never)
  })

  it("blocks account and import actions before reading any user session", async () => {
    await expect(requireAuthIdentity()).rejects.toThrow("Changes are disabled")
    expect(createServerSupabaseClient).not.toHaveBeenCalled()
  })

  it.each([
    signInAction,
    signUpAction,
    forgotPasswordAction,
    updatePasswordAction,
  ])(
    "blocks old authentication forms before any Auth request",
    async (action) => {
      await expect(action({ status: "idle" }, new FormData())).rejects.toThrow(
        "redirect:/"
      )
      expect(createServerSupabaseClient).not.toHaveBeenCalled()
    }
  )

  it("does not create a sign-out loop", async () => {
    await expect(signOutAction()).rejects.toThrow("redirect:/")
    expect(createServerSupabaseClient).not.toHaveBeenCalled()
  })
})
