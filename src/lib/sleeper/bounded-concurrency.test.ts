import { describe, expect, it } from "vitest"

import { mapWithBoundedConcurrency } from "./bounded-concurrency"

describe("mapWithBoundedConcurrency", () => {
  it("never runs more than the configured number and preserves order", async () => {
    let active = 0
    let maximumActive = 0
    const result = await mapWithBoundedConcurrency(
      [5, 4, 3, 2, 1, 0],
      4,
      async (value) => {
        active += 1
        maximumActive = Math.max(maximumActive, active)
        await new Promise((resolve) => setTimeout(resolve, value))
        active -= 1
        return value * 2
      }
    )

    expect(maximumActive).toBe(4)
    expect(result).toEqual([10, 8, 6, 4, 2, 0])
  })

  it("does not launch more work after the first terminal failure", async () => {
    const started: number[] = []

    await expect(
      mapWithBoundedConcurrency([0, 1, 2, 3, 4, 5, 6], 4, async (value) => {
        started.push(value)
        if (value === 0) throw new Error("terminal")
        await new Promise((resolve) => setTimeout(resolve, 5))
        return value
      })
    ).rejects.toThrow("terminal")

    expect(started).toEqual([0, 1, 2, 3])
  })

  it("rejects an invalid concurrency bound", async () => {
    await expect(
      mapWithBoundedConcurrency([1], 0, async (value) => value)
    ).rejects.toThrow("positive safe integer")
  })
})
