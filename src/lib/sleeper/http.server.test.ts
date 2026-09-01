import { afterEach, describe, expect, it, vi } from "vitest"

vi.mock("server-only", () => ({}))

import { sleeperGetJson, sleeperGetJsonWithMetadata } from "./http.server"
import { SleeperClientError } from "./types"

const localEnvironment = {
  NODE_ENV: "test",
  SLEEPER_API_BASE_URL: "http://127.0.0.1:4100/v1",
  SLEEPER_LOCAL_TEST_MODE: "1",
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

  it("returns bounded response metadata without changing JSON callers", async () => {
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

  it("rejects an advertised or decoded response above the configured limit", async () => {
    const advertisedFetch = vi.fn().mockResolvedValue(
      new Response("{}", {
        headers: { "content-length": "1001" },
      })
    )
    vi.stubGlobal("fetch", advertisedFetch)
    await expect(
      sleeperGetJson(["players", "nfl"], {
        environment: localEnvironment,
        maxResponseBytes: 1_000,
        retryDelayMs: 0,
      })
    ).rejects.toMatchObject({ kind: "invalid_response" })
    expect(advertisedFetch).toHaveBeenCalledTimes(1)

    const decodedFetch = vi
      .fn()
      .mockResolvedValue(new Response(JSON.stringify({ value: "too large" })))
    vi.stubGlobal("fetch", decodedFetch)
    await expect(
      sleeperGetJson(["players", "nfl"], {
        environment: localEnvironment,
        maxResponseBytes: 5,
        retryDelayMs: 0,
      })
    ).rejects.toMatchObject({ kind: "invalid_response" })
    expect(decodedFetch).toHaveBeenCalledTimes(1)
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
