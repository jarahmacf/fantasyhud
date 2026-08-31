import type { AuthActionState } from "./types"

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

export interface SignInInput {
  email: string
  password: string
}

export interface SignUpInput extends SignInInput {
  displayName: string
  confirmPassword: string
}

export interface PasswordUpdateInput {
  password: string
  confirmPassword: string
}

type ValidationResult<T> =
  { success: true; data: T } | { success: false; state: AuthActionState }

function valueFrom(formData: FormData, key: string): string {
  const value = formData.get(key)
  return typeof value === "string" ? value : ""
}

function validateEmail(email: string): string | undefined {
  if (!email || email.length > 254 || !emailPattern.test(email)) {
    return "Enter a valid email address."
  }
}

function validatePassword(password: string): string | undefined {
  if (password.length < 8) {
    return "Password must be at least 8 characters."
  }
  if (password.length > 128) {
    return "Password must be 128 characters or fewer."
  }
}

export function validateSignIn(
  formData: FormData
): ValidationResult<SignInInput> {
  const email = valueFrom(formData, "email").trim().toLowerCase()
  const password = valueFrom(formData, "password")
  const fieldErrors: NonNullable<AuthActionState["fieldErrors"]> = {}

  fieldErrors.email = validateEmail(email)
  if (!password) {
    fieldErrors.password = "Enter your password."
  }

  if (fieldErrors.email || fieldErrors.password) {
    return {
      success: false,
      state: {
        status: "error",
        message: "Check the highlighted fields.",
        fieldErrors,
      },
    }
  }

  return { success: true, data: { email, password } }
}

export function validateSignUp(
  formData: FormData
): ValidationResult<SignUpInput> {
  const displayName = valueFrom(formData, "displayName").trim()
  const email = valueFrom(formData, "email").trim().toLowerCase()
  const password = valueFrom(formData, "password")
  const confirmPassword = valueFrom(formData, "confirmPassword")
  const fieldErrors: NonNullable<AuthActionState["fieldErrors"]> = {}

  if (!displayName || displayName.length > 100) {
    fieldErrors.displayName =
      "Display name must be between 1 and 100 characters."
  }
  fieldErrors.email = validateEmail(email)
  fieldErrors.password = validatePassword(password)
  if (confirmPassword !== password) {
    fieldErrors.confirmPassword = "Passwords do not match."
  }

  if (Object.values(fieldErrors).some(Boolean)) {
    return {
      success: false,
      state: {
        status: "error",
        message: "Check the highlighted fields.",
        fieldErrors,
      },
    }
  }

  return {
    success: true,
    data: { displayName, email, password, confirmPassword },
  }
}

export function validateEmailRequest(
  formData: FormData
): ValidationResult<{ email: string }> {
  const email = valueFrom(formData, "email").trim().toLowerCase()
  const error = validateEmail(email)
  if (error) {
    return {
      success: false,
      state: {
        status: "error",
        message: "Check the highlighted field.",
        fieldErrors: { email: error },
      },
    }
  }

  return { success: true, data: { email } }
}

export function validatePasswordUpdate(
  formData: FormData
): ValidationResult<PasswordUpdateInput> {
  const password = valueFrom(formData, "password")
  const confirmPassword = valueFrom(formData, "confirmPassword")
  const fieldErrors: NonNullable<AuthActionState["fieldErrors"]> = {}

  fieldErrors.password = validatePassword(password)
  if (confirmPassword !== password) {
    fieldErrors.confirmPassword = "Passwords do not match."
  }

  if (Object.values(fieldErrors).some(Boolean)) {
    return {
      success: false,
      state: {
        status: "error",
        message: "Check the highlighted fields.",
        fieldErrors,
      },
    }
  }

  return { success: true, data: { password, confirmPassword } }
}
