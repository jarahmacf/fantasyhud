import { describe, expect, it } from "vitest"
import {
  auctionBudgetShare,
  normalizePriceCurve,
  overallPick,
  parseRoundPick,
  positionalMarketCurve,
  priceToPositionRank,
} from "./price-curve"

const rbPrices = [
  { rank: 10, price: 30 },
  { rank: 11, price: 34 },
  { rank: 12, price: 39 },
]

describe("price-implied positional rank", () => {
  it("turns 3.10 in a 12-team draft into pick 34, retaining round notation as text", () => {
    expect(parseRoundPick("3.10", 12)).toBe(34)
    expect(parseRoundPick("3.10", 10)).toBe(30)
    expect(parseRoundPick("3.1", 12)).toBe(25)
    expect(parseRoundPick("2.10", 12)).toBe(22)
    expect(priceToPositionRank(34, rbPrices, "pick")).toMatchObject({
      status: "available",
      rank: 11,
      method: "exact",
    })
  })
  it("interpolates without rounding the stored rank", () => {
    expect(priceToPositionRank(36, rbPrices, "pick")).toMatchObject({
      status: "available",
      rank: 11.4,
      method: "interpolated",
    })
  })
  it("does not invent ranks outside the supplied price range", () => {
    for (const price of [1, 29, 40, 100])
      expect(priceToPositionRank(price, rbPrices, "pick")).toEqual({
        status: "unavailable",
        reason: "outside_market_range",
      })
  })
  it("uses midranks for equal prices and interpolates from that tied anchor", () => {
    const tied = [
      { rank: 10, price: 30 },
      { rank: 11, price: 30 },
      { rank: 12, price: 40 },
    ]
    expect(priceToPositionRank(30, tied, "pick")).toMatchObject({
      rank: 10.5,
      method: "tied",
    })
    expect(priceToPositionRank(35, tied, "pick")).toMatchObject({ rank: 11.25 })
  })
  it("supports one price and an all-tied market only at their observed price", () => {
    expect(
      priceToPositionRank(30, [{ rank: 10, price: 30 }], "pick")
    ).toMatchObject({ rank: 10 })
    expect(
      priceToPositionRank(31, [{ rank: 10, price: 30 }], "pick").status
    ).toBe("unavailable")
    expect(
      priceToPositionRank(
        30,
        [
          { rank: 10, price: 30 },
          { rank: 11, price: 30 },
        ],
        "pick"
      )
    ).toMatchObject({ rank: 10.5 })
  })
  it("uses higher auction expenditure as the more expensive rank", () => {
    const auction = [
      { rank: 10, price: 0.2 },
      { rank: 11, price: 0.15 },
      { rank: 12, price: 0.1 },
    ]
    expect(auctionBudgetShare(30, 200)).toBe(0.15)
    expect(
      priceToPositionRank(auctionBudgetShare(30, 200), auction, "auction")
    ).toMatchObject({ rank: 11 })
    expect(priceToPositionRank(0.125, auction, "auction")).toMatchObject({
      rank: 11.5,
    })
    expect(() => priceToPositionRank(30, auction, "auction")).toThrow(
      /budget share/
    )
  })
  it("derives positional market order independently of input and current roster order", () => {
    const players = [
      { playerId: "c", price: 39, observations: 10 },
      { playerId: "b", price: 34, observations: 10 },
      { playerId: "a", price: 30, observations: 10 },
    ]
    expect(positionalMarketCurve(players, "pick").points).toEqual([
      { rank: 1, price: 30 },
      { rank: 2, price: 34 },
      { rank: 3, price: 39 },
    ])
    expect(players[0]!.playerId).toBe("c")
    expect(() =>
      positionalMarketCurve([...players, players[0]!], "pick")
    ).toThrow(/only once/)
  })
  it.each(
    [
      [],
      [
        { rank: 10, price: 30 },
        { rank: 12, price: 39 },
      ],
      [
        { rank: 10, price: 30 },
        { rank: 10, price: 34 },
      ],
      [
        { rank: 10, price: 34 },
        { rank: 11, price: 30 },
      ],
      [{ rank: 1, price: Number.NaN }],
      [{ rank: 1.5, price: 30 }],
    ].map((points) => ({ points }))
  )("rejects malformed or misleading curves: %j", ({ points }) => {
    expect(() => normalizePriceCurve(points, "pick")).toThrow()
  })
  it("rejects impossible purchases and accidental decimal interpretation", () => {
    expect(() => overallPick(3, 13, 12)).toThrow()
    expect(() => overallPick(0, 1, 12)).toThrow()
    expect(() => parseRoundPick("3.10extra", 12)).toThrow()
    expect(() => parseRoundPick("3", 12)).toThrow()
    expect(() => auctionBudgetShare(201, 200)).toThrow()
    expect(() => auctionBudgetShare(1, 0)).toThrow()
    expect(() => priceToPositionRank(Infinity, rbPrices, "pick")).toThrow()
  })
})
