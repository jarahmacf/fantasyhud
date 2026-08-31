import "server-only"

import { sleeperGetJson, type SleeperHttpOptions } from "./http.server"
import { SleeperClientError, type ResolvedSleeperUser } from "./types"
import { normalizeSleeperUsername } from "./username"

function isPlainObject(value: unknown): value is Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return false
  }

  const prototype = Object.getPrototypeOf(value)
  return prototype === Object.prototype || prototype === null
}

function parseNullableBoundedString(
  value: unknown,
  maximumLength: number
): string | null {
  if (value === null || value === undefined) {
    return null
  }
  if (typeof value !== "string") {
    throw new SleeperClientError("invalid_response")
  }

  const trimmed = value.trim()
  if (trimmed.length === 0) {
    return null
  }
  if (
    trimmed.length > maximumLength ||
    /[\u0000-\u001f\u007f]/u.test(trimmed)
  ) {
    throw new SleeperClientError("invalid_response")
  }

  return trimmed
}

function parseSleeperUser(value: unknown): ResolvedSleeperUser {
  if (value === null) {
    throw new SleeperClientError("not_found")
  }
  if (!isPlainObject(value)) {
    throw new SleeperClientError("invalid_response")
  }

  const userId = value.user_id
  const providerUsername = value.username
  if (
    typeof userId !== "string" ||
    userId.length === 0 ||
    userId !== userId.trim() ||
    userId.length > 255 ||
    /[\u0000-\u001f\u007f]/u.test(userId) ||
    typeof providerUsername !== "string" ||
    providerUsername !== providerUsername.trim()
  ) {
    throw new SleeperClientError("invalid_response")
  }

  let username: string
  try {
    username = normalizeSleeperUsername(providerUsername)
  } catch {
    throw new SleeperClientError("invalid_response")
  }

  const displayName = parseNullableBoundedString(value.display_name, 100)
  const avatarId = parseNullableBoundedString(value.avatar, 255)

  return {
    userId,
    username,
    displayName,
    avatarId,
    avatarUrl: avatarId
      ? `https://sleepercdn.com/avatars/${encodeURIComponent(avatarId)}`
      : null,
  }
}

export async function resolveSleeperUser(
  username: string,
  options: SleeperHttpOptions = {}
): Promise<ResolvedSleeperUser> {
  const normalizedUsername = normalizeSleeperUsername(username)
  const body = await sleeperGetJson(["user", normalizedUsername], options)
  return parseSleeperUser(body)
}
