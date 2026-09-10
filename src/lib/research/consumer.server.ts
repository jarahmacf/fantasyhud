import "server-only"
import { unstable_cache } from "next/cache"
import { readBoundedResponseBody } from "@/lib/sleeper/http.server"
import { normalizeMarket, normalizeStatistics } from "./model"

/** Verified Sleeper consumer feeds. These are separate from the documented v1 API.
 * Only fixed public NFL paths are allowed. There is no browser-selected URL. */
async function consumerRead(
  kind: "projections" | "stats",
  season: number,
  week?: number
) {
  if (
    !Number.isInteger(season) ||
    season < 2020 ||
    season > 2999 ||
    (week !== undefined && (!Number.isInteger(week) || week < 1 || week > 18))
  )
    throw new Error("Invalid source period.")
  let base = "https://api.sleeper.app"
  if (
    process.env.SLEEPER_CONSUMER_TEST_URL &&
    process.env.SLEEPER_LOCAL_TEST_MODE === "1" &&
    process.env.VERCEL_ENV !== "production"
  ) {
    const u = new URL(process.env.SLEEPER_CONSUMER_TEST_URL)
    if (
      u.protocol !== "http:" ||
      !["localhost", "127.0.0.1", "[::1]"].includes(u.hostname)
    )
      throw new Error("Invalid local fixture host.")
    base = u.origin
  }
  const url = `${base}/${kind}/nfl/${season}${week ? `/${week}` : ""}?season_type=regular${kind === "projections" ? "&order_by=adp_ppr" : ""}`
  const controller = new AbortController(),
    timer = setTimeout(() => controller.abort(), 20000)
  try {
    const response = await fetch(url, {
      cache: "no-store",
      redirect: "error",
      headers: { Accept: "application/json" },
      signal: controller.signal,
    })
    if (!response.ok) throw new Error("Sleeper research feed unavailable.")
    const bytes = await readBoundedResponseBody(
      response,
      controller,
      16_000_000
    )
    return {
      data: JSON.parse(new TextDecoder().decode(bytes)) as unknown,
      fetchedAt: new Date().toISOString(),
      url,
    }
  } finally {
    clearTimeout(timer)
  }
}
export const loadMarket = unstable_cache(
  async (season: number) => {
    const r = await consumerRead("projections", season)
    // Strip all projected points/games before this feed can reach the result engine.
    return {
      players: normalizeMarket(r.data, season).filter(
        (p) => Object.keys(p.adp).length
      ),
      fetchedAt: r.fetchedAt,
      url: r.url,
    }
  },
  ["sleeper-explicit-market-v1"],
  { revalidate: 21600 }
)
export const loadWeeklyStatistics = unstable_cache(
  async (season: number, week: number) => {
    const r = await consumerRead("stats", season, week)
    return {
      rows: normalizeStatistics(r.data, season, week),
      fetchedAt: r.fetchedAt,
      url: r.url,
    }
  },
  ["sleeper-weekly-actual-statistics-v1"],
  { revalidate: 120 }
)
