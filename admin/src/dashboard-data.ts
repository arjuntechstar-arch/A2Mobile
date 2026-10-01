export type CollectionRow = {
  group: string;
  contributions_paise: number;
  count: number;
  gateway_fees_paise: number;
};

export type CollectionPoint = CollectionRow & { date: string };

export function collectionSeries(rows: CollectionRow[], days: number, now = new Date()): CollectionPoint[] {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Kolkata", year: "numeric", month: "2-digit", day: "2-digit",
  }).formatToParts(now);
  const part = (type: string) => Number(parts.find((p) => p.type === type)!.value);
  const today = Date.UTC(part("year"), part("month") - 1, part("day"));
  const grouped = new Map(rows.map((row) => [row.group, row]));
  return Array.from({ length: days }, (_, index) => {
    const date = new Date(today - (days - index - 1) * 86400000).toISOString().slice(0, 10);
    const row = grouped.get(date);
    return { group: date, date, contributions_paise: row?.contributions_paise ?? 0,
      count: row?.count ?? 0, gateway_fees_paise: row?.gateway_fees_paise ?? 0 };
  });
}

export function collectionTotals(points: CollectionPoint[]) {
  return points.reduce((total, point) => ({
    contributions_paise: total.contributions_paise + point.contributions_paise,
    count: total.count + point.count,
    gateway_fees_paise: total.gateway_fees_paise + point.gateway_fees_paise,
  }), { contributions_paise: 0, count: 0, gateway_fees_paise: 0 });
}

export const chartMoney = (paise: number) => new Intl.NumberFormat("en-IN", {
  style: "currency", currency: "INR", maximumFractionDigits: 2,
}).format(paise / 100);

export const chartDate = (date: string) => new Intl.DateTimeFormat("en-IN", {
  day: "2-digit", month: "short", timeZone: "Asia/Kolkata",
}).format(new Date(`${date}T00:00:00Z`));
