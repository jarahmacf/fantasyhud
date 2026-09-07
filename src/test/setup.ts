import "@testing-library/jest-dom/vitest"

import { cleanup } from "@testing-library/react"
import { afterEach, vi } from "vitest"

vi.stubEnv("FANTASYHUD_TEMPORARY_ACCESS", "off")
vi.mock("server-only", () => ({}))

function createMediaQueryList(query: string): MediaQueryList {
  return {
    matches: false,
    media: query,
    onchange: null,
    addListener: () => undefined,
    removeListener: () => undefined,
    addEventListener: () => undefined,
    removeEventListener: () => undefined,
    dispatchEvent: () => false,
  }
}

Object.defineProperty(window, "matchMedia", {
  configurable: true,
  value: createMediaQueryList,
})

afterEach(() => {
  cleanup()
})
