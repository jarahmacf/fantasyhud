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
  maxResponseBytes?: number
  environment?: SleeperHttpEnvironment
}

export interface SleeperJsonResponse {
  data: unknown
  responseBytes: number
  fetchedAt: string
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

async function readBoundedResponseBody(
  response: Response,
  controller: AbortController,
  maxResponseBytes?: number
): Promise<ArrayBuffer> {
  if (!response.body || typeof response.body.getReader !== "function") {
    const body = await response.arrayBuffer()
    if (maxResponseBytes !== undefined && body.byteLength > maxResponseBytes) {
      controller.abort()
      throw new SleeperClientError("invalid_response")
    }
    return body
  }

  const reader = response.body.getReader()
  const chunks: Uint8Array[] = []
  let responseBytes = 0

  try {
    while (true) {
      const { done, value } = await reader.read()
      if (done) break
      if (!value || value.byteLength === 0) continue

      const nextResponseBytes = responseBytes + value.byteLength
      if (
        !Number.isSafeInteger(nextResponseBytes) ||
        (maxResponseBytes !== undefined && nextResponseBytes > maxResponseBytes)
      ) {
        try {
          await reader.cancel()
        } catch {
          // The request is aborted below even when stream cancellation fails.
        }
        controller.abort()
        throw new SleeperClientError("invalid_response")
      }

      chunks.push(value)
      responseBytes = nextResponseBytes
    }
  } finally {
    reader.releaseLock()
  }

  const body = new Uint8Array(responseBytes)
  let offset = 0
  for (const chunk of chunks) {
    body.set(chunk, offset)
    offset += chunk.byteLength
  }
  return body.buffer
}

async function fetchWithTimeout(
  url: string,
  timeoutMs: number,
  maxResponseBytes?: number
): Promise<
  | { response: Response; body: null; responseBytes: 0; fetchedAt: null }
  | {
      response: Response
      body: ArrayBuffer
      responseBytes: number
      fetchedAt: string
    }
> {
  const controller = new AbortController()
  const timeout = setTimeout(() => controller.abort(), timeoutMs)

  try {
    const response = await fetch(url, {
      method: "GET",
      headers: { Accept: "application/json" },
      cache: "no-store",
      signal: controller.signal,
    })

    if (!response.ok) {
      return { response, body: null, responseBytes: 0, fetchedAt: null }
    }

    const contentLength = response.headers.get("content-length")?.trim()
    if (maxResponseBytes !== undefined && contentLength) {
      const advertisedBytes = Number(contentLength)
      if (
        Number.isFinite(advertisedBytes) &&
        advertisedBytes > maxResponseBytes
      ) {
        controller.abort()
        throw new SleeperClientError("invalid_response")
      }
    }

    const body = await readBoundedResponseBody(
      response,
      controller,
      maxResponseBytes
    )

    return {
      response,
      body,
      responseBytes: body.byteLength,
      fetchedAt: new Date().toISOString(),
    }
  } catch (error) {
    if (error instanceof SleeperClientError) throw error
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
  const response = await sleeperGetJsonWithMetadata(pathSegments, options)
  return response.data
}

export async function sleeperGetJsonWithMetadata(
  pathSegments: readonly string[],
  options: SleeperHttpOptions = {}
): Promise<SleeperJsonResponse> {
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
  const maxResponseBytes = options.maxResponseBytes

  if (
    maxResponseBytes !== undefined &&
    (!Number.isSafeInteger(maxResponseBytes) || maxResponseBytes < 1)
  ) {
    throw new SleeperClientError("invalid_response")
  }

  for (let attempt = 1; attempt <= maximumAttempts; attempt += 1) {
    let result: Awaited<ReturnType<typeof fetchWithTimeout>>
    try {
      result = await fetchWithTimeout(url, timeoutMs, maxResponseBytes)
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

    const { response } = result

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
      if (!result.body || !result.fetchedAt) {
        throw new SleeperClientError("invalid_response")
      }

      return {
        data: JSON.parse(new TextDecoder().decode(result.body)) as unknown,
        responseBytes: result.responseBytes,
        fetchedAt: result.fetchedAt,
      }
    } catch {
      throw new SleeperClientError("invalid_response")
    }
  }

  throw new SleeperClientError("unavailable")
}
