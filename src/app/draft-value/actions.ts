"use server"
import { revalidatePath } from "next/cache"
import { importPrimaryAccountDrafts } from "@/lib/drafts/import.server"
import type { DraftImportActionState } from "@/lib/drafts/types"

export async function importCurrentSleeperDraftsAction(
  _previous: DraftImportActionState,
  _form: FormData
): Promise<DraftImportActionState> {
  void _previous
  void _form
  const result = await importPrimaryAccountDrafts()
  revalidatePath("/draft-value")
  revalidatePath("/")
  return { status: result.status, message: result.message }
}
