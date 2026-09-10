import {
  loadTrackerDetail,
  loadTrackerOverview,
} from "@/lib/tracker/source.server"
export const maxDuration = 300
export async function GET(request: Request) {
  try {
    const token = new URL(request.url).searchParams.get("league")
    const data = token
      ? await loadTrackerDetail(token)
      : await loadTrackerOverview()
    return Response.json(data, {
      headers: { "Cache-Control": "private, no-store" },
    })
  } catch {
    return Response.json(
      {
        error:
          "The tracker could not refresh. Your saved imports are unchanged; try again shortly.",
      },
      { status: 503, headers: { "Cache-Control": "private, no-store" } }
    )
  }
}
