export interface AuthIdentity {
  id: string
  email: string | null
}

export interface AuthActionState {
  status: "idle" | "error" | "success"
  message?: string
  fieldErrors?: Partial<
    Record<"displayName" | "email" | "password" | "confirmPassword", string>
  >
}

export const initialAuthActionState: AuthActionState = { status: "idle" }
