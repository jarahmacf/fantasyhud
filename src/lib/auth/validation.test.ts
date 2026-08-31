import { describe, expect, it } from "vitest"

import {
  validateEmailRequest,
  validatePasswordUpdate,
  validateSignIn,
  validateSignUp,
} from "./validation"

function form(values: Record<string, string>) {
  const data = new FormData()
  Object.entries(values).forEach(([name, value]) => data.set(name, value))
  return data
}

describe("auth validation", () => {
  it("normalizes a valid sign-in email without changing the password", () => {
    expect(
      validateSignIn(
        form({ email: " USER@Example.COM ", password: " secret value " })
      )
    ).toEqual({
      success: true,
      data: { email: "user@example.com", password: " secret value " },
    })
  })

  it("validates every sign-up field", () => {
    const result = validateSignUp(
      form({
        displayName: " ",
        email: "invalid",
        password: "short",
        confirmPassword: "different",
      })
    )
    expect(result.success).toBe(false)
    if (!result.success) {
      expect(result.state.fieldErrors).toMatchObject({
        displayName: expect.any(String),
        email: expect.any(String),
        password: expect.any(String),
        confirmPassword: expect.any(String),
      })
    }
  })

  it("accepts a complete sign-up", () => {
    expect(
      validateSignUp(
        form({
          displayName: "  Test User ",
          email: "test@example.com",
          password: "correct horse battery staple",
          confirmPassword: "correct horse battery staple",
        })
      )
    ).toMatchObject({
      success: true,
      data: { displayName: "Test User", email: "test@example.com" },
    })
  })

  it("validates generic email requests without account disclosure", () => {
    expect(validateEmailRequest(form({ email: "bad" })).success).toBe(false)
    expect(
      validateEmailRequest(form({ email: "valid@example.com" })).success
    ).toBe(true)
  })

  it("requires matching strong replacement passwords", () => {
    expect(
      validatePasswordUpdate(
        form({ password: "eightchars", confirmPassword: "different" })
      ).success
    ).toBe(false)
    expect(
      validatePasswordUpdate(
        form({ password: "eightchars", confirmPassword: "eightchars" })
      ).success
    ).toBe(true)
  })
})
