import "@testing-library/jest-dom/vitest"

import { cleanup } from "@testing-library/react"
import { afterEach } from "vitest"

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
