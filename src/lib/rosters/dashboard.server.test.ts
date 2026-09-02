import { describe, expect, it, vi } from "vitest"

vi.mock("server-only", () => ({}))

import {
  deriveMembershipAnnotationStates,
  RosterDashboardQueryError,
  sourceArrayCount,
} from "./dashboard.server"

const knownSourceMetadata = {
  annotation_source_state: {
    starters: "known",
    reserve: "known",
    taxi: "known",
    keepers: "known",
  },
  normalization_warning_fields: [],
}

describe("roster dashboard source-state derivation", () => {
  it("derives exact nullable source-array counts and excludes only the verified starter placeholder", () => {
    expect(sourceArrayCount(null)).toBeNull()
    expect(sourceArrayCount([])).toBe(0)
    expect(sourceArrayCount(["player-a", "player-b"])).toBe(2)
    expect(sourceArrayCount(["player-a", "0", "0"], "0")).toBe(1)
  })

  it("renders known booleans as yes or no and unknown observations as not reported", () => {
    expect(
      deriveMembershipAnnotationStates(knownSourceMetadata, {
        isStarter: true,
        isReserve: false,
        isTaxi: true,
        isKeeper: false,
      })
    ).toEqual({
      starterState: "yes",
      reserveState: "no",
      taxiState: "yes",
      keeperState: "no",
    })

    expect(
      deriveMembershipAnnotationStates(
        {
          annotation_source_state: {
            starters: "unknown",
            reserve: "unknown",
            taxi: "unknown",
            keepers: "unknown",
          },
          normalization_warning_fields: ["starter_slot_alignment"],
        },
        {
          isStarter: true,
          isReserve: true,
          isTaxi: true,
          isKeeper: true,
        }
      )
    ).toEqual({
      starterState: "not_reported",
      reserveState: "not_reported",
      taxiState: "not_reported",
      keeperState: "not_reported",
    })
  })

  it.each([
    null,
    {},
    {
      annotation_source_state: {
        starters: "known",
        reserve: "known",
        taxi: "known",
      },
      normalization_warning_fields: [],
    },
    {
      annotation_source_state: {
        starters: "known",
        reserve: "known",
        taxi: "known",
        keepers: "malformed",
      },
      normalization_warning_fields: [],
    },
    {
      ...knownSourceMetadata,
      normalization_warning_fields: ["unsafe.warning"],
    },
    {
      ...knownSourceMetadata,
      unreviewed: true,
    },
    {
      ...knownSourceMetadata,
      oversized: "x".repeat(32_768),
    },
  ])("fails safely on malformed annotation metadata", (sourceMetadata) => {
    expect(() =>
      deriveMembershipAnnotationStates(sourceMetadata, {
        isStarter: false,
        isReserve: false,
        isTaxi: false,
        isKeeper: false,
      })
    ).toThrow(RosterDashboardQueryError)
  })
})
