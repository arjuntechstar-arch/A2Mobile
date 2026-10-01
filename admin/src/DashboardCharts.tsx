import { useEffect, useRef, useState } from "react";
import { ApiClient } from "./api";
import { chartDate, chartMoney, collectionSeries, collectionTotals, CollectionRow } from "./dashboard-data";

type Props = {
  api: ApiClient;
  summary: Record<string, number>;
  canViewEnrollments: boolean;
  onNavigate: (page: string) => void;
};

export function DashboardCharts({ api, summary, canViewEnrollments, onNavigate }: Props) {
  const [rows, setRows] = useState<CollectionRow[] | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [days, setDays] = useState(30);
  const [metric, setMetric] = useState<"amount" | "count">("amount");
  const [selected, setSelected] = useState(29);
  const [enrollment, setEnrollment] = useState<"active" | "completed" | null>(null);
  const [workload, setWorkload] = useState("overdue");
  const [plotWidth, setPlotWidth] = useState(760);
  const plotRef = useRef<SVGSVGElement>(null);

  useEffect(() => {
    if (rows === null || !plotRef.current) return;
    const plot = plotRef.current;
    const observer = new ResizeObserver(() => setPlotWidth(Math.max(200, plot.clientWidth)));
    observer.observe(plot);
    return () => observer.disconnect();
  }, [rows === null]);

  async function refresh() {
    if (busy) return;
    setBusy(true);
    setError("");
    try {
      setRows(await api.request("/admin/reports/collections?group=day"));
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "Could not load collection trends.");
    } finally {
      setBusy(false);
    }
  }

  useEffect(() => {
    let live = true;
    setBusy(true);
    api.request("/admin/reports/collections?group=day")
      .then((data) => { if (live) setRows(data); })
      .catch((cause) => { if (live) setError(cause instanceof Error ? cause.message : "Could not load collection trends."); })
      .finally(() => { if (live) setBusy(false); });
    return () => { live = false; };
  }, [api]);

  const points = collectionSeries(rows ?? [], days);
  const totals = collectionTotals(points);
  const index = Math.min(selected, points.length - 1);
  const inspected = points[index];
  const values = points.map((point) => metric === "amount" ? point.contributions_paise : point.count);
  const roughStep = Math.max(metric === "amount" ? 10000 : 3, ...values) / 3;
  const magnitude = 10 ** Math.floor(Math.log10(roughStep));
  const multiplier = [1, 2, 5, 10].find((value) => value * magnitude >= roughStep)!;
  const ceiling = (metric === "count" ? Math.ceil(multiplier * magnitude) : multiplier * magnitude) * 3;
  const x = (i: number) => 64 + i * (plotWidth - 92) / (days - 1);
  const y = (value: number) => 210 - value / ceiling * 182;
  const line = values.map((value, i) => `${i ? "L" : "M"}${x(i)},${y(value)}`).join(" ");
  const active = summary.active_enrollments ?? 0;
  const completed = summary.completed_enrollments ?? 0;
  const enrollmentTotal = active + completed;
  const activeShare = enrollmentTotal ? active / enrollmentTotal : 0;
  const circle = 2 * Math.PI * 58;
  const selectedEnrollment = enrollment === "active" ? active : enrollment === "completed" ? completed : enrollmentTotal;
  const tasks = [
    { key: "overdue", label: "Overdue installments", value: summary.overdue_installments ?? 0, color: "amber", description: "Unpaid installments currently marked overdue. Open the overdue list to follow up with customers." },
    { key: "today", label: "Installments due today", value: summary.due_today ?? 0, color: "blue", description: "Unpaid installments whose due date is today in the store calendar." },
    { key: "redemptions", label: "Pending redemptions", value: summary.pending_redemptions ?? 0, color: "teal", description: "Customer redemption requests waiting to be processed." },
  ];
  const taskMax = Math.max(1, ...tasks.map((task) => task.value));

  return <section className="dashboard-charts" aria-label="Dashboard insights">
    <article className="chart-card collections-chart">
      <div className="chart-heading"><div><h2>Collection trends</h2><p>Captured contributions, before gateway fees · India calendar</p></div>
        <button type="button" disabled={busy} onClick={() => void refresh()} aria-label="Refresh collection chart">{busy ? "Refreshing…" : "Refresh chart"}</button>
      </div>
      <div className="chart-controls">
        <div className="chart-toggle" role="group" aria-label="Collection period">{[7, 30, 90].map((period) => <button key={period} aria-pressed={days === period} onClick={() => { setDays(period); setSelected(period - 1); }}>Last {period} days</button>)}</div>
        <div className="chart-toggle" role="group" aria-label="Collection measure">{(["amount", "count"] as const).map((value) => <button key={value} aria-pressed={metric === value} onClick={() => setMetric(value)}>{value === "amount" ? "Collections" : "Payment count"}</button>)}</div>
      </div>
      {error && <p className="chart-error" role="alert">{error} <button disabled={busy} onClick={() => void refresh()}>Try again</button></p>}
      {rows === null ? <p className="chart-empty" role="status">{busy ? "Loading collection history…" : "Collection history is unavailable."}</p> : <>
        <div className="chart-stats"><div><span>Collected in period</span><strong>{chartMoney(totals.contributions_paise)}</strong></div><div><span>Captured payments</span><strong>{totals.count.toLocaleString("en-IN")}</strong></div><div><span>Daily average</span><strong>{chartMoney(totals.contributions_paise / days)}</strong></div></div>
        {totals.count === 0 && <p className="chart-empty">No captured payments in this period.</p>}
        <svg ref={plotRef} className="trend-svg" viewBox={`0 0 ${plotWidth} 260`} tabIndex={0} role="group" aria-label={`${metric === "amount" ? "Collections" : "Payment count"} over the last ${days} days. Use left and right arrow keys to inspect dates.`}
          onKeyDown={(event) => {
            const next = event.key === "ArrowLeft" ? Math.max(0, index - 1) : event.key === "ArrowRight" ? Math.min(days - 1, index + 1) : event.key === "Home" ? 0 : event.key === "End" ? days - 1 : null;
            if (next !== null) { event.preventDefault(); setSelected(next); }
          }}>
          {[0, 1, 2, 3].map((tick) => {
            const value = ceiling * tick / 3;
            return <g key={tick}><line x1="64" x2={x(days - 1)} y1={y(value)} y2={y(value)} className="chart-gridline" /><text x="54" y={y(value) + 4} textAnchor="end" className="chart-axis">{metric === "count" ? value : new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", notation: "compact", maximumFractionDigits: 1 }).format(value / 100)}</text></g>;
          })}
          <path d={`${line} L${x(days - 1)},210 L64,210 Z`} fill="#2563eb" fillOpacity=".08" />
          <path d={line} className="chart-line" />
          <line x1={x(index)} x2={x(index)} y1="28" y2="210" className="chart-inspection-line" />
          {points.map((point, i) => <g key={point.date} onMouseEnter={() => setSelected(i)} onClick={() => setSelected(i)}><rect x={x(i) - (plotWidth - 92) / (days - 1) / 2} y="20" width={(plotWidth - 92) / (days - 1)} height="200" fill="transparent" /><circle cx={x(i)} cy={y(values[i])} r={i === index ? 5 : 2.5} fill="#2563eb" /></g>)}
          {[0, Math.floor((days - 1) / 2), days - 1].map((i) => <text key={i} x={x(i)} y="242" textAnchor="middle" className="chart-axis">{chartDate(points[i].date)}</text>)}
        </svg>
        <div className="chart-readout" aria-live="polite"><strong>{chartDate(inspected.date)}</strong><span>{chartMoney(inspected.contributions_paise)} collected</span><span>{inspected.count} captured {inspected.count === 1 ? "payment" : "payments"}</span><span>Gateway fees: {chartMoney(inspected.gateway_fees_paise)}</span></div>
        <p className="chart-hint">Hover, tap, or focus the chart and use arrow keys to inspect each day.</p>
      </>}
    </article>

    <article className="chart-card"><div className="chart-heading"><div><h2>Enrollment activity</h2><p>Active and completed customer memberships</p></div></div>
      <div className="enrollment-visual"><svg viewBox="0 0 160 160" aria-hidden="true">
        <circle cx="80" cy="80" r="58" fill="none" stroke="#e2e8f0" strokeWidth="18" />
        {enrollmentTotal > 0 && <g transform="rotate(-90 80 80)"><circle cx="80" cy="80" r="58" fill="none" stroke="#2563eb" strokeWidth="18" strokeDasharray={`${circle * activeShare} ${circle}`} onMouseEnter={() => setEnrollment("active")} /><circle cx="80" cy="80" r="58" fill="none" stroke="#16a34a" strokeWidth="18" strokeDasharray={`${circle * (1 - activeShare)} ${circle}`} strokeDashoffset={-circle * activeShare} onMouseEnter={() => setEnrollment("completed")} /></g>}
        <text x="80" y="78" textAnchor="middle" className="donut-number">{selectedEnrollment.toLocaleString("en-IN")}</text><text x="80" y="100" textAnchor="middle" className="chart-axis">{enrollment ?? "Total shown"}</text>
      </svg><div className="chart-legend">{(["active", "completed"] as const).map((status) => {
        const count = status === "active" ? active : completed;
        return <button key={status} aria-pressed={enrollment === status} onClick={() => setEnrollment(enrollment === status ? null : status)}><span className={`legend-dot ${status}`} />{status === "active" ? "Active" : "Completed"}<strong>{count.toLocaleString("en-IN")}</strong><small>{enrollmentTotal ? Math.round(count / enrollmentTotal * 100) : 0}%</small></button>;
      })}</div></div>
      {enrollmentTotal === 0 && <p className="chart-empty">No active or completed enrollments yet.</p>}
      <p className="chart-hint">Select a status to inspect its share. Other enrollment statuses are excluded.</p>
      {canViewEnrollments && <button onClick={() => onNavigate("enrollments")}>View enrollments</button>}
    </article>

    <article className="chart-card"><div className="chart-heading"><div><h2>Payments & follow-up</h2><p>Current workload across payments and redemption</p></div></div>
      <div className="workload-bars">{tasks.map((task) => <button key={task.key} className={`workload-item ${task.color}`} aria-pressed={workload === task.key} onClick={() => setWorkload(task.key)}><span>{task.label}<strong>{task.value.toLocaleString("en-IN")}</strong></span><span className="workload-track"><span style={{ width: `${task.value / taskMax * 100}%` }} /></span></button>)}</div>
      <p className="workload-description" aria-live="polite">{tasks.find((task) => task.key === workload)!.description}</p>
      <p className="chart-hint">Counts are independent; due-today and overdue installments can overlap.</p>
      {canViewEnrollments && <button onClick={() => onNavigate("overdue")}>View overdue installments</button>}
    </article>
  </section>;
}
