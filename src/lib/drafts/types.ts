export type DraftImportActionState = {
  status: "idle" | "running" | "success" | "partial" | "error"
  message: string | null
}
