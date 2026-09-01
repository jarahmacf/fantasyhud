import { afterEach, describe, expect, it, vi } from "vitest"

vi.mock("server-only", () => ({}))

import { sleeperGetJson, sleeperGetJsonWithMetadata } from "./http.server"
import { SleeperClientError } from "./types"

const localEnvironment = {
  NODE_ENV: "test",
  SLEEPER_API_BASE_URL: "http://127.0.0.1:4100/v1",
  SLEEPER_LOCAL_TEST_MODE: "1",
}

function exactJsonStream(
  byteLength: number,
  options: {
    chunkSize?: number
    onCancel?: () => void
    onEnqueue?: (totalBytes: number) => void
  } = {}
): ReadableStream<Uint8Array> {
  const json = new Uint8Array([123, 125])
  const chunkSize = options.chunkSize ?? 256 * 1024
  let emittedBytes = 0

  return new ReadableStream<Uint8Array>({
    pull(controller) {
      const remainingBytes = byteLength - emittedBytes
      if (remainingBytes <= 0) {
        controller.close()
        return
      }

      if (emittedBytes === 0) {
        const firstChunk = json.subarray(
          0,
          Math.min(json.byteLength, byteLength)
        )
        controller.enqueue(firstChunk)
        emittedBytes += firstChunk.byteLength
        options.onEnqueue?.(emittedBytes)
        return
      }

      const currentChunkSize = Math.min(chunkSize, remainingBytes)
      const chunk = new Uint8Array(currentChunkSize)
      chunk.fill(32)
      controller.enqueue(chunk)
      emittedBytes += currentChunkSize
      options.onEnqueue?.(emittedBytes)
    },
    cancel() {
      options.onCancel?.()
    },
  })
}

afterEach(() => {
  vi.unstubAllGlobals()
  vi.restoreAllMocks()
})

describe("sleeperGetJson", () => {
  it("uses the official endpoint and safe GET options", async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValue(new Response(JSON.stringify({ ok: true })))
    vi.stubGlobal("fetch", fetchMock)

    await sleeperGetJson(["state", "nfl"], {
      environment: { NODE_ENV: "production" },
      retryDelayMs: 0,
    })

    expect(fetchMock).toHaveBeenCalledWith(
      "https://api.sleeper.app/v1/state/nfl",
      expect.objectContaining({
        method: "GET",
        headers: { Accept: "application/json" },
        cache: "no-store",
        signal: expect.any(AbortSignal),
      })
    )
  })

  it("URL-encodes every path segment", async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValue(new Response(JSON.stringify([])))
    vi.stubGlobal("fetch", fetchMock)

    await sleeperGetJson(["user", "id/with slash", "leagues", "nfl", "2026"], {
      environment: localEnvironment,
      retryDelayMs: 0,
    })

    expect(fetchMock).toHaveBeenCalledWith(
      "http://127.0.0.1:4100/v1/user/id%2Fwith%20slash/leagues/nfl/2026",
      expect.any(Object)
    )
  })

  it("retries a network failure once", async () => {
    const fetchMock = vi
      .fn()
      .mockRejectedValueOnce(new TypeError("network"))
      .mockResolvedValueOnce(new Response(JSON.stringify({ ok: true })))
    vi.stubGlobal("fetch", fetchMock)

    await expect(
      sleeperGetJson(["state", "nfl"], {
        environment: localEnvironment,
        retryDelayMs: 0,
      })
    ).resolves.toEqual({ ok: true })
    expect(fetchMock).toHaveBeenCalledTimes(2)
  })

  it("times out and retries only once", async () => {
    const fetchMock = vi.fn((_url: string, init?: RequestInit) => {
      return new Promise<Response>((_resolve, reject) => {
        init?.signal?.addEventListener("abort", () => {
          reject(new DOMException("aborted", "AbortError"))
        })
      })
    })
    vi.stubGlobal("fetch", fetchMock)

    await expect(
      sleeperGetJson(["state", "nfl"], {
        environment: localEnvironment,
        timeoutMs: 1,
        retryDelayMs: 0,
      })
    ).rejects.toMatchObject({ kind: "timeout" })
    expect(fetchMock).toHaveBeenCalledTimes(2)
  })

  it("retries HTTP 429 once with bounded Retry-After", async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(
        new Response(null, { status: 429, headers: { "retry-after": "0" } })
      )
      .mockResolvedValueOnce(new Response(JSON.stringify({ ok: true })))
    vi.stubGlobal("fetch", fetchMock)

    await sleeperGetJson(["state", "nfl"], {
      environment: localEnvironment,
      retryDelayMs: 0,
    })
    expect(fetchMock).toHaveBeenCalledTimes(2)
  })

  it("retries HTTP 5xx once and stops after two attempts", async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValue(new Response(null, { status: 503 }))
    vi.stubGlobal("fetch", fetchMock)

    await expect(
      sleeperGetJson(["state", "nfl"], {
        environment: localEnvironment,
        retryDelayMs: 0,
      })
    ).rejects.toMatchObject({ kind: "unavailable" })
    expect(fetchMock).toHaveBeenCalledTimes(2)
  })

  it("does not retry ordinary HTTP failures", async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValue(new Response(null, { status: 400 }))
    vi.stubGlobal("fetch", fetchMock)

    await expect(
      sleeperGetJson(["state", "nfl"], {
        environment: localEnvironment,
        retryDelayMs: 0,
      })
    ).rejects.toMatchObject({ kind: "unavailable" })
    expect(fetchMock).toHaveBeenCalledTimes(1)
  })

  it("rejects malformed JSON without exposing it", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(new Response("raw-provider-secret{"))
    )

    let caught: unknown
    try {
      await sleeperGetJson(["state", "nfl"], {
        environment: localEnvironment,
        retryDelayMs: 0,
      })
    } catch (error) {
      caught = error
    }
    expect(caught).toBeInstanceOf(SleeperClientError)
    expect((caught as Error).message).not.toContain("raw-provider-secret")
  })

  it("accepts a response below the former limit and returns exact metadata", async () => {
    const body = JSON.stringify({ ok: true })
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(new Response(body)))

    const result = await sleeperGetJsonWithMetadata(["players", "nfl"], {
      environment: localEnvironment,
      maxResponseBytes: 1_000,
      retryDelayMs: 0,
    })

    expect(result.data).toEqual({ ok: true })
    expect(result.responseBytes).toBe(new TextEncoder().encode(body).byteLength)
    expect(new Date(result.fetchedAt).toISOString()).toBe(result.fetchedAt)
  })

  it("accepts a streamed response between the former and new limits", async () => {
    const responseBytes = 15_000_001
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(new Response(exactJsonStream(responseBytes)))
    )

    await expect(
      sleeperGetJsonWithMetadata(["players", "nfl"], {
        environment: localEnvironment,
        maxResponseBytes: 25_000_000,
        retryDelayMs: 0,
      })
    ).resolves.toMatchObject({ data: {}, responseBytes })
  })

  it("accepts a streamed response exactly at the configured limit", async () => {
    const responseBytes = 25_000_000
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(new Response(exactJsonStream(responseBytes)))
    )

    await expect(
      sleeperGetJsonWithMetadata(["players", "nfl"], {
        environment: localEnvironment,
        maxResponseBytes: responseBytes,
        retryDelayMs: 0,
      })
    ).resolves.toMatchObject({ data: {}, responseBytes })
  })

  it("rejects a streamed response one byte above the configured limit", async () => {
    const decodedFetch = vi
      .fn()
      .mockResolvedValue(new Response(exactJsonStream(25_000_001)))
    vi.stubGlobal("fetch", decodedFetch)

    await expect(
      sleeperGetJsonWithMetadata(["players", "nfl"], {
        environment: localEnvironment,
        maxResponseBytes: 25_000_000,
        retryDelayMs: 0,
      })
    ).rejects.toMatchObject({ kind: "invalid_response" })
    expect(decodedFetch).toHaveBeenCalledTimes(1)
  })

  it("rejects an advertised response above the limit before body consumption", async () => {
    const getReader = vi.fn()
    const arrayBuffer = vi.fn()
    const advertisedFetch = vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      headers: new Headers({ "content-length": "25000001" }),
      body: { getReader },
      arrayBuffer,
    } as unknown as Response)
    vi.stubGlobal("fetch", advertisedFetch)

    await expect(
      sleeperGetJson(["players", "nfl"], {
        environment: localEnvironment,
        maxResponseBytes: 25_000_000,
        retryDelayMs: 0,
      })
    ).rejects.toMatchObject({ kind: "invalid_response" })
    expect(advertisedFetch).toHaveBeenCalledTimes(1)
    expect(getReader).not.toHaveBeenCalled()
    expect(arrayBuffer).not.toHaveBeenCalled()
  })

  it("stops an over-limit stream immediately, cancels it, aborts it, and does not retry", async () => {
    let emittedBytes = 0
    let cancelled = false
    let aborted = false
    const body = exactJsonStream(5_000, {
      chunkSize: 600,
      onCancel: () => {
        cancelled = true
      },
      onEnqueue: (totalBytes) => {
        emittedBytes = totalBytes
      },
    })
    const decodedFetch = vi.fn((_url: string, init?: RequestInit) => {
      init?.signal?.addEventListener("abort", () => {
        aborted = true
      })
      return Promise.resolve(new Response(body))
    })
    vi.stubGlobal("fetch", decodedFetch)

    await expect(
      sleeperGetJson(["players", "nfl"], {
        environment: localEnvironment,
        maxResponseBytes: 1_000,
        retryDelayMs: 0,
      })
    ).rejects.toMatchObject({ kind: "invalid_response" })
    expect(decodedFetch).toHaveBeenCalledTimes(1)
    expect(emittedBytes).toBeGreaterThan(1_000)
    expect(emittedBytes).toBeLessThanOrEqual(1_802)
    expect(emittedBytes).toBeLessThan(5_000)
    expect(cancelled).toBe(true)
    expect(aborted).toBe(true)
  })

  it("retains the final size check when a response body reader is unavailable", async () => {
    const body = new TextEncoder().encode("{}" + " ".repeat(998)).buffer
    const arrayBuffer = vi.fn().mockResolvedValue(body)
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        ok: true,
        status: 200,
        headers: new Headers(),
        body: {},
        arrayBuffer,
      } as unknown as Response)
    )

    await expect(
      sleeperGetJsonWithMetadata(["players", "nfl"], {
        environment: localEnvironment,
        maxResponseBytes: 1_000,
        retryDelayMs: 0,
      })
    ).resolves.toMatchObject({ data: {}, responseBytes: 1_000 })
    expect(arrayBuffer).toHaveBeenCalledTimes(1)
  })

  it("rejects a fallback response above the limit without retrying", async () => {
    const body = new TextEncoder().encode("{} ").buffer
    const fallbackFetch = vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      headers: new Headers(),
      body: null,
      arrayBuffer: vi.fn().mockResolvedValue(body),
    } as unknown as Response)
    vi.stubGlobal("fetch", fallbackFetch)

    await expect(
      sleeperGetJson(["players", "nfl"], {
        environment: localEnvironment,
        maxResponseBytes: 2,
        retryDelayMs: 0,
      })
    ).rejects.toMatchObject({ kind: "invalid_response" })
    expect(fallbackFetch).toHaveBeenCalledTimes(1)
  })

  it("fails closed on arbitrary Production override origins", async () => {
    vi.stubGlobal("fetch", vi.fn())

    await expect(
      sleeperGetJson(["state", "nfl"], {
        environment: {
          NODE_ENV: "production",
          SLEEPER_API_BASE_URL: "https://attacker.test/v1",
        },
      })
    ).rejects.toBeInstanceOf(SleeperClientError)
    expect(fetch).not.toHaveBeenCalled()
  })

  it("allows loopback only with the explicit local Production test flag", async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValue(new Response(JSON.stringify({ ok: true })))
    vi.stubGlobal("fetch", fetchMock)

    await sleeperGetJson(["state", "nfl"], {
      environment: {
        NODE_ENV: "production",
        SLEEPER_API_BASE_URL: "http://127.0.0.1:4100/v1",
        SLEEPER_LOCAL_TEST_MODE: "1",
      },
      retryDelayMs: 0,
    })
    expect(fetchMock).toHaveBeenCalledTimes(1)
  })
})
