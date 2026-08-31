import { afterEach, describe, expect, it, vi } from "vitest"

vi.mock("server-only", () => ({}))

import { resolveSleeperUser } from "./client.server"
import { SleeperClientError } from "./types"

const localEnvironment = {
  NODE_ENV: "test",
  SLEEPER_API_BASE_URL: "http://127.0.0.1:4100/v1",
  SLEEPER_LOCAL_TEST_MODE: "1",
}

function validResponse(overrides: Record<string, unknown> = {}) {
  return new Response(
    JSON.stringify({
      user_id: "900719925474099312345",
      username: "CanonicalUser",
      display_name: "Canonical Display",
      avatar: "avatar-id",
      ...overrides,
    }),
    { status: 200, headers: { "content-type": "application/json" } }
  )
}

afterEach(() => {
  vi.unstubAllGlobals()
  vi.restoreAllMocks()
})

describe("resolveSleeperUser", () => {
  it("defaults Production to the official Sleeper endpoint", async () => {
    const fetchMock = vi.fn().mockResolvedValue(validResponse())
    vi.stubGlobal("fetch", fetchMock)

    await resolveSleeperUser("official-user", {
      environment: { NODE_ENV: "production" },
      retryDelayMs: 0,
    })

    expect(fetchMock).toHaveBeenCalledWith(
      "https://api.sleeper.app/v1/user/official-user",
      expect.any(Object)
    )
  })

  it("URL-encodes the submitted username and uses safe fetch options", async () => {
    const fetchMock = vi.fn().mockResolvedValue(validResponse())
    vi.stubGlobal("fetch", fetchMock)

    await resolveSleeperUser("name+plus", {
      environment: localEnvironment,
      retryDelayMs: 0,
    })

    expect(fetchMock).toHaveBeenCalledWith(
      "http://127.0.0.1:4100/v1/user/name%2Bplus",
      expect.objectContaining({
        method: "GET",
        headers: { Accept: "application/json" },
        cache: "no-store",
        signal: expect.any(AbortSignal),
      })
    )
  })

  it("returns a validated canonical identity and keeps a large ID as text", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(validResponse()))

    await expect(
      resolveSleeperUser("submitted-user", {
        environment: localEnvironment,
        retryDelayMs: 0,
      })
    ).resolves.toEqual({
      userId: "900719925474099312345",
      username: "CanonicalUser",
      displayName: "Canonical Display",
      avatarId: "avatar-id",
      avatarUrl: "https://sleepercdn.com/avatars/avatar-id",
    })
  })

  it("supports null display names and avatars", async () => {
    vi.stubGlobal(
      "fetch",
      vi
        .fn()
        .mockResolvedValue(validResponse({ display_name: null, avatar: null }))
    )

    await expect(
      resolveSleeperUser("submitted-user", {
        environment: localEnvironment,
        retryDelayMs: 0,
      })
    ).resolves.toEqual(
      expect.objectContaining({
        displayName: null,
        avatarId: null,
        avatarUrl: null,
      })
    )
  })

  it("encodes avatar IDs when building the CDN URL", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(validResponse({ avatar: "avatar/value" }))
    )

    await expect(
      resolveSleeperUser("submitted-user", {
        environment: localEnvironment,
        retryDelayMs: 0,
      })
    ).resolves.toEqual(
      expect.objectContaining({
        avatarUrl: "https://sleepercdn.com/avatars/avatar%2Fvalue",
      })
    )
  })

  it("maps HTTP 404 to not found without retrying", async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValue(new Response(null, { status: 404 }))
    vi.stubGlobal("fetch", fetchMock)

    await expect(
      resolveSleeperUser("missing", {
        environment: localEnvironment,
        retryDelayMs: 0,
      })
    ).rejects.toMatchObject({ kind: "not_found" })
    expect(fetchMock).toHaveBeenCalledTimes(1)
  })

  it("maps a valid JSON null response to not found", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(new Response("null", { status: 200 }))
    )

    await expect(
      resolveSleeperUser("missing", {
        environment: localEnvironment,
        retryDelayMs: 0,
      })
    ).rejects.toMatchObject({ kind: "not_found" })
  })

  it("rejects malformed JSON as an invalid response", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(new Response("{", { status: 200 }))
    )

    await expect(
      resolveSleeperUser("bad-json", {
        environment: localEnvironment,
        retryDelayMs: 0,
      })
    ).rejects.toMatchObject({ kind: "invalid_response" })
  })

  it("rejects a wrong-shaped successful response", async () => {
    vi.stubGlobal(
      "fetch",
      vi
        .fn()
        .mockResolvedValue(
          new Response(JSON.stringify({ username: "missing-id" }))
        )
    )

    await expect(
      resolveSleeperUser("bad-shape", {
        environment: localEnvironment,
        retryDelayMs: 0,
      })
    ).rejects.toMatchObject({ kind: "invalid_response" })
  })

  it("rejects numeric provider IDs", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(validResponse({ user_id: 9007199254740993 }))
    )

    await expect(
      resolveSleeperUser("numeric-id", {
        environment: localEnvironment,
        retryDelayMs: 0,
      })
    ).rejects.toMatchObject({ kind: "invalid_response" })
  })

  it("retries HTTP 429 once and honors a bounded Retry-After", async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(
        new Response(null, { status: 429, headers: { "retry-after": "0" } })
      )
      .mockResolvedValueOnce(validResponse())
    vi.stubGlobal("fetch", fetchMock)

    await expect(
      resolveSleeperUser("rate-limited", {
        environment: localEnvironment,
        retryDelayMs: 0,
      })
    ).resolves.toMatchObject({ username: "CanonicalUser" })
    expect(fetchMock).toHaveBeenCalledTimes(2)
  })

  it("retries HTTP 500 once", async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(new Response(null, { status: 500 }))
      .mockResolvedValueOnce(validResponse())
    vi.stubGlobal("fetch", fetchMock)

    await expect(
      resolveSleeperUser("transient", {
        environment: localEnvironment,
        retryDelayMs: 0,
      })
    ).resolves.toMatchObject({ username: "CanonicalUser" })
    expect(fetchMock).toHaveBeenCalledTimes(2)
  })

  it("retries a timeout once", async () => {
    const timeoutError = Object.assign(new Error("aborted"), {
      name: "AbortError",
    })
    const fetchMock = vi
      .fn()
      .mockRejectedValueOnce(timeoutError)
      .mockResolvedValueOnce(validResponse())
    vi.stubGlobal("fetch", fetchMock)

    await expect(
      resolveSleeperUser("timeout", {
        environment: localEnvironment,
        retryDelayMs: 0,
      })
    ).resolves.toMatchObject({ username: "CanonicalUser" })
    expect(fetchMock).toHaveBeenCalledTimes(2)
  })

  it("does not retry an ordinary HTTP 400", async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValue(new Response(null, { status: 400 }))
    vi.stubGlobal("fetch", fetchMock)

    await expect(
      resolveSleeperUser("bad-request", {
        environment: localEnvironment,
        retryDelayMs: 0,
      })
    ).rejects.toMatchObject({ kind: "unavailable" })
    expect(fetchMock).toHaveBeenCalledTimes(1)
  })

  it("makes at most two attempts", async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValue(new Response(null, { status: 503 }))
    vi.stubGlobal("fetch", fetchMock)

    await expect(
      resolveSleeperUser("still-down", {
        environment: localEnvironment,
        retryDelayMs: 0,
      })
    ).rejects.toMatchObject({ kind: "unavailable" })
    expect(fetchMock).toHaveBeenCalledTimes(2)
  })

  it("fails closed when Production is configured with another origin", async () => {
    vi.stubGlobal("fetch", vi.fn())

    await expect(
      resolveSleeperUser("user", {
        environment: {
          NODE_ENV: "production",
          SLEEPER_API_BASE_URL: "https://attacker.test/v1",
        },
      })
    ).rejects.toBeInstanceOf(SleeperClientError)
    expect(fetch).not.toHaveBeenCalled()
  })

  it("requires an explicit test opt-in for loopback in a Production build", async () => {
    vi.stubGlobal("fetch", vi.fn())

    await expect(
      resolveSleeperUser("user", {
        environment: {
          NODE_ENV: "production",
          SLEEPER_API_BASE_URL: "http://127.0.0.1:4100/v1",
        },
      })
    ).rejects.toBeInstanceOf(SleeperClientError)
    expect(fetch).not.toHaveBeenCalled()
  })

  it("allows the explicit loopback test opt-in for a local Production build", async () => {
    const fetchMock = vi.fn().mockResolvedValue(validResponse())
    vi.stubGlobal("fetch", fetchMock)

    await resolveSleeperUser("fixture-user", {
      environment: {
        NODE_ENV: "production",
        SLEEPER_API_BASE_URL: "http://127.0.0.1:4100/v1",
        SLEEPER_LOCAL_TEST_MODE: "1",
      },
      retryDelayMs: 0,
    })

    expect(fetchMock).toHaveBeenCalledTimes(1)
  })

  it("rejects the loopback test opt-in in Vercel Production", async () => {
    vi.stubGlobal("fetch", vi.fn())

    await expect(
      resolveSleeperUser("user", {
        environment: {
          NODE_ENV: "production",
          VERCEL_ENV: "production",
          SLEEPER_API_BASE_URL: "http://127.0.0.1:4100/v1",
          SLEEPER_LOCAL_TEST_MODE: "1",
        },
      })
    ).rejects.toBeInstanceOf(SleeperClientError)
    expect(fetch).not.toHaveBeenCalled()
  })

  it("never includes raw provider content in an error", async () => {
    const rawSecret = "raw-provider-content-must-not-escape"
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(
        new Response(JSON.stringify({ unexpected: rawSecret }), {
          status: 200,
        })
      )
    )

    let caught: unknown
    try {
      await resolveSleeperUser("bad-shape", {
        environment: localEnvironment,
        retryDelayMs: 0,
      })
    } catch (error) {
      caught = error
    }

    expect(caught).toBeInstanceOf(SleeperClientError)
    expect((caught as Error).message).not.toContain(rawSecret)
  })
})
