import "server-only"

import { SleeperClientError, type ResolvedSleeperUser } from "./types"
import { normalizeSleeperUsername } from "./username"

const officialSleeperApiBaseUrl = "https://api.sleeper.app/v1"
const defaultTimeoutMs = 5_000
const defaultRetryDelayMs = 250
const maximumRetryAfterMs = 1_000
const maximumAttempts = 2

interface SleeperClientEnvironment {
  NODE_ENV?: string
  SLEEPER_API_BASE_URL?: string
  SLEEPER_LOCAL_TEST_MODE?: string
  VERCEL_ENV?: string
}

interface SleeperClientOptions {
  timeoutMs?: number
  retryDelayMs?: number
  environment?: SleeperClientEnvironment
}

function getSleeperApiBaseUrl(
  environment: SleeperClientEnvironment = process.env
): string {
  const configured = environment.SLEEPER_API_BASE_URL?.trim()
  if (!configured) {
    return officialSleeperApiBaseUrl
  }

  let parsed: URL
  try {
    parsed = new URL(configured)
  } catch {
    throw new SleeperClientError("unavailable")
  }

  const normalized = parsed.toString().replace(/\/$/u, "")
  const isLocalHttp =
    parsed.protocol === "http:" &&
    (parsed.hostname === "127.0.0.1" ||
      parsed.hostname === "localhost" ||
      parsed.hostname === "[::1]")
  const isExplicitLocalTest =
    isLocalHttp &&
    environment.SLEEPER_LOCAL_TEST_MODE === "1" &&
    environment.VERCEL_ENV !== "production"

  if (
    environment.NODE_ENV === "production" &&
    normalized !== officialSleeperApiBaseUrl &&
    !isExplicitLocalTest
  ) {
    throw new SleeperClientError("unavailable")
  }

  if (parsed.protocol === "http:") {
    if (!isLocalHttp || environment.VERCEL_ENV === "production") {
      throw new SleeperClientError("unavailable")
    }
  } else if (parsed.protocol !== "https:") {
    throw new SleeperClientError("unavailable")
  }

  return normalized
}

function getRetryDelay(response: Response, fallbackMs: number): number {
  const retryAfter = response.headers.get("retry-after")?.trim()
  if (!retryAfter) {
    return fallbackMs
  }

  const seconds = Number(retryAfter)
  if (Number.isFinite(seconds) && seconds >= 0) {
    return Math.min(seconds * 1_000, maximumRetryAfterMs)
  }

  const retryDate = Date.parse(retryAfter)
  if (Number.isNaN(retryDate)) {
    return fallbackMs
  }

  return Math.min(Math.max(retryDate - Date.now(), 0), maximumRetryAfterMs)
}

function wait(milliseconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, milliseconds))
}

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

async function fetchWithTimeout(
  url: string,
  timeoutMs: number
): Promise<Response> {
  const controller = new AbortController()
  const timeout = setTimeout(() => controller.abort(), timeoutMs)

  try {
    return await fetch(url, {
      method: "GET",
      headers: { Accept: "application/json" },
      cache: "no-store",
      signal: controller.signal,
    })
  } catch (error) {
    if (
      controller.signal.aborted ||
      (error instanceof Error &&
        (error.name === "AbortError" || error.name === "TimeoutError"))
    ) {
      throw new SleeperClientError("timeout")
    }
    throw new SleeperClientError("unavailable")
  } finally {
    clearTimeout(timeout)
  }
}

export async function resolveSleeperUser(
  username: string,
  options: SleeperClientOptions = {}
): Promise<ResolvedSleeperUser> {
  const normalizedUsername = normalizeSleeperUsername(username)
  const baseUrl = getSleeperApiBaseUrl(options.environment)
  const url = `${baseUrl}/user/${encodeURIComponent(normalizedUsername)}`
  const timeoutMs = options.timeoutMs ?? defaultTimeoutMs
  const retryDelayMs = options.retryDelayMs ?? defaultRetryDelayMs

  for (let attempt = 1; attempt <= maximumAttempts; attempt += 1) {
    let response: Response
    try {
      response = await fetchWithTimeout(url, timeoutMs)
    } catch (error) {
      if (
        error instanceof SleeperClientError &&
        (error.kind === "timeout" || error.kind === "unavailable") &&
        attempt < maximumAttempts
      ) {
        await wait(retryDelayMs)
        continue
      }
      throw error
    }

    if (response.status === 404) {
      throw new SleeperClientError("not_found")
    }

    if (response.status === 429 || response.status >= 500) {
      if (attempt < maximumAttempts) {
        await wait(getRetryDelay(response, retryDelayMs))
        continue
      }
      throw new SleeperClientError("unavailable")
    }

    if (!response.ok) {
      throw new SleeperClientError("unavailable")
    }

    let body: unknown
    try {
      body = await response.json()
    } catch {
      throw new SleeperClientError("invalid_response")
    }

    return parseSleeperUser(body)
  }

  throw new SleeperClientError("unavailable")
}
