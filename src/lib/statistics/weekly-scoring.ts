/** Audited subset of nflverse weekly box-score columns; no default-PPR totals. */
export const WEEKLY_SCORING_VERSION = "nflverse-weekly-box-score/v1"
const fields = {
  pass_yd: "passing_yards",
  pass_td: "passing_tds",
  pass_int: "passing_interceptions",
  pass_cmp: "completions",
  pass_att: "attempts",
  pass_2pt: "passing_2pt_conversions",
  rush_yd: "rushing_yards",
  rush_td: "rushing_tds",
  rush_att: "carries",
  rush_fd: "rushing_first_downs",
  rush_2pt: "rushing_2pt_conversions",
  rec: "receptions",
  rec_yd: "receiving_yards",
  rec_td: "receiving_tds",
  rec_fd: "receiving_first_downs",
  rec_2pt: "receiving_2pt_conversions",
} as const
const receptionBonuses: Record<string, string> = {
  bonus_rec_rb: "RB",
  bonus_rec_wr: "WR",
  bonus_rec_te: "TE",
}
export type WeeklyScoringResult =
  | {
      status: "available"
      points: number
      version: typeof WEEKLY_SCORING_VERSION
    }
  | {
      status: "unavailable"
      unsupportedRuleKeys: string[]
      missingStatKeys: string[]
    }

/** Unknown nonzero rules block the entire exact context, including special teams and distance bonuses. */
export function scoreWeeklyBoxScore(
  scoringSettings: Readonly<Record<string, unknown>>,
  position: string,
  stats: Readonly<Record<string, unknown>>
): WeeklyScoringResult {
  const unsupportedRuleKeys: string[] = []
  const missingStatKeys = new Set<string>()
  let points = 0
  for (const [rule, weight] of Object.entries(scoringSettings).sort(
    ([a], [b]) => (a < b ? -1 : a > b ? 1 : 0)
  )) {
    if (typeof weight !== "number" || !Number.isFinite(weight)) {
      unsupportedRuleKeys.push(rule)
      continue
    }
    if (weight === 0) continue
    const bonusPosition = Object.hasOwn(receptionBonuses, rule)
      ? receptionBonuses[rule]
      : undefined
    if (bonusPosition && !["QB", "RB", "WR", "TE"].includes(position)) {
      unsupportedRuleKeys.push(rule)
      continue
    }
    // This version explicitly proves other-position reception bonuses irrelevant.
    if (bonusPosition && bonusPosition !== position) continue
    const field = bonusPosition
      ? "receptions"
      : Object.hasOwn(fields, rule)
        ? fields[rule as keyof typeof fields]
        : undefined
    if (!field) {
      unsupportedRuleKeys.push(rule)
      continue
    }
    const statistic = stats[field]
    if (typeof statistic !== "number" || !Number.isFinite(statistic)) {
      missingStatKeys.add(field)
      continue
    }
    points += statistic * weight
  }
  if (
    unsupportedRuleKeys.length ||
    missingStatKeys.size ||
    !Number.isFinite(points)
  )
    return {
      status: "unavailable",
      unsupportedRuleKeys,
      missingStatKeys: [...missingStatKeys].sort(),
    }
  return {
    status: "available",
    points: Math.round(points * 1_000_000) / 1_000_000,
    version: WEEKLY_SCORING_VERSION,
  }
}
