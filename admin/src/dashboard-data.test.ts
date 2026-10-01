import { describe, expect, it } from "vitest";
import { collectionSeries, collectionTotals, CollectionRow } from "./dashboard-data";

describe("collection series", () => {
  const history: CollectionRow[] = [
    { group: "2026-09-30", contributions_paise: 100000, count: 2, gateway_fees_paise: 2000 },
    { group: "2026-09-28", contributions_paise: 250000, count: 3, gateway_fees_paise: 4000 },
    { group: "2026-01-01", contributions_paise: 900000, count: 9, gateway_fees_paise: 5000 },
  ];

  it("uses the India calendar across the UTC day boundary and fills missing dates", () => {
    const series = collectionSeries(history, 4, new Date("2026-09-30T20:00:00Z"));
    expect(series.map((point) => point.date)).toEqual(["2026-09-28", "2026-09-29", "2026-09-30", "2026-10-01"]);
    expect(series.map((point) => point.count)).toEqual([3, 0, 2, 0]);
    expect(series[1].contributions_paise).toBe(0);
  });

  it("totals only the selected period and keeps money in paise", () => {
    expect(collectionTotals(collectionSeries(history, 4, new Date("2026-09-30T20:00:00Z"))))
      .toEqual({ contributions_paise: 350000, count: 5, gateway_fees_paise: 6000 });
    expect(collectionTotals(collectionSeries(history, 1, new Date("2026-09-30T12:00:00Z"))))
      .toEqual({ contributions_paise: 100000, count: 2, gateway_fees_paise: 2000 });
  });

  it("returns a complete zero series without inventing activity", () => {
    const series = collectionSeries([], 90, new Date("2026-10-01T00:00:00Z"));
    expect(series).toHaveLength(90);
    expect(collectionTotals(series)).toEqual({ contributions_paise: 0, count: 0, gateway_fees_paise: 0 });
  });
});
