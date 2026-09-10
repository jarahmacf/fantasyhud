import { loadPlayerProfile, loadResearch } from "@/lib/research/source.server"
export const maxDuration = 300
export async function GET(request: Request) {
  const params = new URL(request.url).searchParams
  try {
    const player = params.get("player")
    return Response.json(
      player
        ? await loadPlayerProfile(player, params.get("context"))
        : await loadResearch(),
      { headers: { "Cache-Control": "private, no-store" } }
    )
  } catch {
    return Response.json(
      {
        error:
          "Research could not refresh. Previous observations are retained; please retry.",
      },
      { status: 503, headers: { "Cache-Control": "private, no-store" } }
    )
  }
}
