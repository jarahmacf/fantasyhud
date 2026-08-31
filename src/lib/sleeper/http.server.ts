import "server-only"

import { SleeperClientError } from "./types"

const officialSleeperApiBaseUrl = "https://api.sleeper.app/v1"
const defaultTimeoutMs = 5_000
const defaultRetryDelayMs = 250
const maximumRetryAfterMs = 1_000
const maximumAttempts = 2

export interface SleeperHttpEnvironment {
  NODE_ENV?: string
  SLEEPER_API_BASE_URL?: string
  SLEEPER_LOCAL_TEST_MODE?: string
  VERCEL_ENV?: string
}

export interface SleeperHttpOptions {
  timeoutMs?: number
  retryDelayMs?: number
  environment?: SleeperHttpEnvironment
}

function getSleeperApiBaseUrl(
  environment: SleeperHttpEnvironment = process.env
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

  if (normalized !== officialSleeperApiBaseUrl && !isExplicitLocalTest) {
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

export async function sleeperGetJson(
  pathSegments: readonly string[],
  options: SleeperHttpOptions = {}
): Promise<unknown> {
  if (
    pathSegments.length === 0 ||
    pathSegments.some(
      (segment) =>
        typeof segment !== "string" ||
        segment.length === 0 ||
        segment.length > 255 ||
        /[\u0000-\u001f\u007f]/u.test(segment)
    )
  ) {
    throw new SleeperClientError("invalid_response")
  }

  const baseUrl = getSleeperApiBaseUrl(options.environment)
  const encodedPath = pathSegments.map(encodeURIComponent).join("/")
  const url = `${baseUrl}/${encodedPath}`
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

    try {
      return await response.json()
    } catch {
      throw new SleeperClientError("invalid_response")
    }
  }

  throw new SleeperClientError("unavailable")
}
