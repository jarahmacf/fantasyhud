import { SleeperClientError } from "./types"

export const draftNormalizationVersion = "sleeper-draft/v1"
export const maximumDrafts = 1_000
export const maximumDraftPicks = 10_000

type SourceObject = Record<string, unknown>
export function invalidDraft(): never {
  throw new SleeperClientError("invalid_response")
}
export function exactDraftToken(value: unknown): string {
  if (
    typeof value !== "string" ||
    !value ||
    value.length > 255 ||
    value !== value.trim() ||
    /[\u0000-\u001f\u007f]/u.test(value)
  )
    invalidDraft()
  return value
}
function object(value: unknown, bytes = 131_072): SourceObject {
  if (
    !value ||
    typeof value !== "object" ||
    Array.isArray(value) ||
    new TextEncoder().encode(JSON.stringify(value)).length > bytes
  )
    invalidDraft()
  return structuredClone(value) as SourceObject
}
function integer(value: unknown, max = 1_000, min = 1): number {
  if (
    typeof value !== "number" ||
    !Number.isSafeInteger(value) ||
    value < min ||
    value > max
  )
    invalidDraft()
  return value
}
function optionalInteger(value: unknown, max = 1_000, min = 1) {
  return value == null ? null : integer(value, max, min)
}
function timestamp(value: unknown): string | null {
  if (value == null || value === 0) return null
  const time = integer(value, 32_503_680_000_000)
  return new Date(time).toISOString()
}
function display(value: unknown, max = 255): string | null {
  if (value == null || value === "") return null
  if (typeof value !== "string" || /[\u0000-\u001f\u007f]/u.test(value))
    return null
  const normalized = value.trim()
  return normalized && normalized.length <= max ? normalized : null
}
function rosterId(value: unknown): number | null {
  if (value == null || value === "") return null
  if (typeof value === "string") {
    if (!/^[1-9][0-9]{0,6}$/u.test(value)) invalidDraft()
    return integer(Number(value), 1_000_000)
  }
  return integer(value, 1_000_000)
}
function exactMap(
  value: unknown,
  slots: boolean
): Record<string, number> | null {
  if (value == null) return null
  const source = object(value)
  if (Object.keys(source).length > 1_000) invalidDraft()
  return Object.fromEntries(
    Object.entries(source)
      .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))
      .map(([key, val]) => {
        if (slots) {
          if (!/^[1-9][0-9]{0,3}$/u.test(key)) invalidDraft()
          integer(Number(key))
        } else exactDraftToken(key)
        return [key, integer(val, slots ? 1_000_000 : 1_000)]
      })
  )
}

export function normalizeDraftDetail(
  value: unknown,
  season: number,
  expectedDraftId?: string,
  expectedLeagueId?: string
) {
  integer(season, 2999, 1900)
  const source = object(value, 1_000_000)
  const externalDraftId = exactDraftToken(source.draft_id)
  const externalLeagueId =
    source.league_id == null || source.league_id === ""
      ? null
      : exactDraftToken(source.league_id)
  if (
    source.sport !== "nfl" ||
    source.season !== String(season) ||
    (expectedDraftId !== undefined && externalDraftId !== expectedDraftId) ||
    (expectedLeagueId !== undefined && externalLeagueId !== expectedLeagueId)
  )
    invalidDraft()
  const settings = object(source.settings)
  const metadata =
    source.metadata == null ? {} : object(source.metadata, 65_536)
  const draftType = exactDraftToken(source.type)
  const teamCount = optionalInteger(settings.teams)
  const roundCount = optionalInteger(settings.rounds)
  const draftOrder = exactMap(source.draft_order, false)
  const slotToRoster = exactMap(source.slot_to_roster_id, true)
  if (
    teamCount !== null &&
    (Object.values(draftOrder ?? {}).some((x) => x > teamCount) ||
      Object.keys(slotToRoster ?? {}).some((x) => Number(x) > teamCount))
  )
    invalidDraft()
  let creators: string[] | null = null
  if (source.creators != null) {
    if (!Array.isArray(source.creators) || source.creators.length > 1_000)
      invalidDraft()
    creators = source.creators.map(exactDraftToken)
    if (new Set(creators).size !== creators.length) invalidDraft()
  }
  return {
    externalDraftId,
    externalLeagueId,
    season,
    seasonType: exactDraftToken(source.season_type),
    draftType,
    status: exactDraftToken(source.status),
    teamCount,
    roundCount,
    pickTimerSeconds: optionalInteger(settings.pick_timer, 86_400, 0),
    startTime: timestamp(source.start_time),
    createdAt: timestamp(source.created),
    lastPickedAt: timestamp(source.last_picked),
    lastMessageAt: timestamp(source.last_message_time),
    lastMessageId:
      source.last_message_id == null || source.last_message_id === ""
        ? null
        : exactDraftToken(source.last_message_id),
    name: display(metadata.name),
    description: display(metadata.description, 4096),
    settings,
    metadata,
    creators,
    draftOrder,
    slotToRoster,
    // Source enum semantics are not documented; a name or numeric player_type is not proof.
    draftPoolType: "unknown" as const,
  }
}
export type NormalizedDraftDetail = ReturnType<typeof normalizeDraftDetail>

export function normalizeDraftList(
  value: unknown,
  season: number,
  expectedLeagueId?: string
) {
  if (!Array.isArray(value) || value.length > maximumDrafts) invalidDraft()
  const drafts = value.map((row) =>
    normalizeDraftDetail(row, season, undefined, expectedLeagueId)
  )
  if (new Set(drafts.map((row) => row.externalDraftId)).size !== drafts.length)
    invalidDraft()
  return drafts.sort((a, b) => (a.externalDraftId < b.externalDraftId ? -1 : 1))
}

export function normalizeDraftBoard(
  detail: NormalizedDraftDetail,
  value: unknown
) {
  if (!Array.isArray(value) || value.length > maximumDraftPicks) invalidDraft()
  const picks = value
    .map((row) => {
      const source = object(row, 100_000)
      if (source.draft_id !== detail.externalDraftId) invalidDraft()
      const externalPlayerId = exactDraftToken(source.player_id)
      if (externalPlayerId === "0") invalidDraft()
      const pickNo = integer(source.pick_no, 1_000_000)
      const round = integer(source.round)
      const draftSlot = integer(source.draft_slot)
      if (
        (detail.teamCount !== null && draftSlot > detail.teamCount) ||
        (detail.roundCount !== null && round > detail.roundCount)
      )
        invalidDraft()
      if (source.is_keeper != null && typeof source.is_keeper !== "boolean")
        invalidDraft()
      const metadata =
        source.metadata == null ? {} : object(source.metadata, 32_768)
      if (metadata.player_id != null && metadata.player_id !== externalPlayerId)
        invalidDraft()
      const position =
        metadata.position == null || metadata.position === ""
          ? null
          : exactDraftToken(metadata.position)
      if (position !== null && !/^[A-Z0-9_]{1,32}$/u.test(position))
        invalidDraft()
      const team =
        metadata.team == null || metadata.team === ""
          ? null
          : exactDraftToken(metadata.team)
      if (team !== null && !/^[A-Z0-9_]{1,32}$/u.test(team)) invalidDraft()
      const pickedBy =
        source.picked_by == null || source.picked_by === ""
          ? null
          : exactDraftToken(source.picked_by)
      return {
        externalPlayerId,
        pickNo,
        round,
        draftSlot,
        pickedBy,
        externalRosterId: rosterId(source.roster_id),
        isKeeper: (source.is_keeper ?? null) as boolean | null,
        // Unpublished auction amount fields require a separate audited source adapter.
        auctionAmount: null,
        displayName: display(
          [display(metadata.first_name), display(metadata.last_name)]
            .filter(Boolean)
            .join(" ")
        ),
        position,
        team,
        entityType:
          position === "DEF" ? "team_defense" : position ? "player" : "unknown",
        status: display(metadata.status, 64),
        injuryStatus: display(metadata.injury_status, 64),
        metadata,
        sourceMetadata: object(
          {
            picked_by_source: source.picked_by ?? null,
            roster_id_source: source.roster_id ?? null,
            unreviewed_fields: Object.fromEntries(
              Object.entries(source).filter(
                ([key]) =>
                  ![
                    "draft_id",
                    "player_id",
                    "pick_no",
                    "round",
                    "draft_slot",
                    "picked_by",
                    "roster_id",
                    "is_keeper",
                    "metadata",
                    "reactions",
                  ].includes(key)
              )
            ),
          },
          32_768
        ),
      }
    })
    .sort((a, b) => a.pickNo - b.pickNo)
  if (
    new Set(picks.map((p) => p.pickNo)).size !== picks.length ||
    new Set(picks.map((p) => p.externalPlayerId)).size !== picks.length ||
    picks.some((p, index) => p.pickNo !== index + 1)
  )
    invalidDraft()
  const slotNumbers =
    detail.teamCount === null
      ? [
          ...new Set([
            ...Object.values(detail.draftOrder ?? {}),
            ...Object.keys(detail.slotToRoster ?? {}).map(Number),
            ...picks.map((p) => p.draftSlot),
          ]),
        ].sort((a, b) => a - b)
      : Array.from({ length: detail.teamCount }, (_, index) => index + 1)
  const slots = slotNumbers.map((draftSlot) => ({
    draftSlot,
    sourceUserIds:
      detail.draftOrder === null
        ? null
        : Object.entries(detail.draftOrder)
            .filter(([, slot]) => slot === draftSlot)
            .map(([user]) => user)
            .sort(),
    externalRosterId: detail.slotToRoster?.[String(draftSlot)] ?? null,
  }))
  // A successful endpoint is not proof of a full completed board when dimensions are absent.
  const complete =
    detail.status === "complete" &&
    detail.teamCount !== null &&
    detail.roundCount !== null &&
    picks.length === detail.teamCount * detail.roundCount &&
    slots.length === detail.teamCount
  return {
    detail,
    slots,
    picks,
    complete,
    containsKeeperPicks: picks.some((p) => p.isKeeper === true)
      ? true
      : picks.some((p) => p.isKeeper === null)
        ? null
        : false,
  }
}
export type NormalizedDraftBoard = ReturnType<typeof normalizeDraftBoard>

export function resolveDraftParticipation(
  board: NormalizedDraftBoard,
  accountId: string,
  includedInUserList: boolean,
  confirmedRosterId: number | null
) {
  exactDraftToken(accountId)
  const candidates = new Set<number>()
  for (const slot of board.slots) {
    if (slot.sourceUserIds?.includes(accountId)) candidates.add(slot.draftSlot)
    if (
      confirmedRosterId !== null &&
      slot.externalRosterId === confirmedRosterId
    )
      candidates.add(slot.draftSlot)
  }
  for (const pick of board.picks)
    if (pick.pickedBy === accountId) candidates.add(pick.draftSlot)
  if (candidates.size > 1) invalidDraft()
  if (candidates.size === 1) {
    const draftSlot = [...candidates][0]
    const slot = board.slots.find((s) => s.draftSlot === draftSlot)!
    const attributed = board.picks.filter(
      (p) => p.draftSlot === draftSlot && p.pickedBy !== null
    )
    const contradictory =
      slot.sourceUserIds !== null &&
      slot.sourceUserIds.length > 0 &&
      !slot.sourceUserIds.includes(accountId) &&
      attributed.some((p) => p.pickedBy !== accountId)
    if (!contradictory && includedInUserList)
      return { status: "confirmed" as const, draftSlot }
  }
  const completeNegative =
    !includedInUserList &&
    candidates.size === 0 &&
    board.detail.draftOrder !== null &&
    board.slots.every(
      (s) => s.sourceUserIds !== null && s.sourceUserIds.length > 0
    ) &&
    board.complete
  return {
    status: completeNegative
      ? ("not_participant" as const)
      : ("unresolved" as const),
    draftSlot: null,
  }
}
