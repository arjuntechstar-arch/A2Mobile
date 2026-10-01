/// <reference types="vite/client" />
import { FormEvent, useEffect, useState } from "react";
import { createRoot } from "react-dom/client";
import { ApiClient, CurrentUser, baseUrl } from "./api";
import { exportCsv } from "./csv";
import "./styles.css";
import { DashboardCharts } from "./DashboardCharts";
import { RowAction } from "./RowAction";

type Row = Record<string, any>;
const api = new ApiClient();
const money = (n: number) =>
  new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR" }).format(
    n / 100,
  );
const dashboardPrimary = ["monthly_collection_paise", "received_today_paise", "overdue_installments", "active_schemes"];
function DashboardMetric({ name, value }: { name: string; value: any }) {
  const tone = name.includes("collection") || name === "received_today_paise" ? "collections" : name.includes("overdue") ? "overdue" : name.includes("completed") ? "completed" : name === "active_schemes" ? "active" : "";
  return <article className={tone ? `metric-${tone}` : ""}><span>{name.replaceAll("_", " ").replace("paise", "")}</span><strong>{name.endsWith("_paise") ? money(value) : value}</strong></article>;
}
const names: Record<string, string> = {
  dashboard: "Dashboard",
  customers: "Customers",
  schemes: "Schemes",
  enrollments: "Enrollments",
  installments: "Installments",
  kyc: "KYC",
  payments: "Payments",
  orders: "Reconciliation",
  overdue: "Overdue",
  completed: "Completed schemes",
  redemptions: "Redemptions",
  refunds: "Refunds",
  reports: "Reports",
  notifications: "Notifications",
  banners: "Banners",
  support: "Support",
  stores: "Stores",
  audit: "Audit logs",
  settings: "Settings",
  users: "Staff accounts",
  system: "Service configuration",
};
const permissions: Record<string, string> = {
  dashboard: "report:read",
  customers: "customer:read",
  schemes: "scheme:manage",
  enrollments: "enrollment:read",
  installments: "enrollment:read",
  kyc: "kyc:review",
  payments: "payment:read",
  orders: "reconciliation:manage",
  overdue: "enrollment:read",
  completed: "enrollment:read",
  redemptions: "redemption:process",
  refunds: "refund:read",
  reports: "report:read",
  notifications: "notification:manage",
  banners: "settings:manage",
  support: "support:manage",
  stores: "settings:manage",
  audit: "audit:read",
  settings: "settings:manage",
  users: "admin:manage",
  system: "settings:manage",
};
const navigationGroups = [
  { label: "Overview", pages: ["dashboard", "reports"] },
  { label: "Customers", pages: ["customers", "kyc", "support"] },
  { label: "Schemes & Payments", pages: ["schemes", "enrollments", "installments", "payments", "overdue", "completed"] },
  { label: "Operations", pages: ["orders", "redemptions", "refunds", "notifications", "banners"] },
  { label: "Settings", pages: ["stores", "settings", "users", "audit", "system"] },
];
const navigationIcons: Record<string, string> = {
  dashboard: "M3 3h7v7H3z M14 3h7v7h-7z M3 14h7v7H3z M14 14h7v7h-7z",
  reports: "M4 3v18h17 M8 16v-5 M13 16V7 M18 16V4",
  customers: "M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2 M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8 M17 4a4 4 0 0 1 0 8 M22 21v-2a4 4 0 0 0-3-4",
  kyc: "M12 3l8 4v6c0 5-8 9-8 9s-8-4-8-9V7z M8 12l3 3 5-6",
  support: "M4 14v-3a8 8 0 0 1 16 0v3 M4 11H2v6h4v-6z M20 11h2v6h-4v-6z M20 17v3h-7",
  schemes: "M12 3l9 5-9 5-9-5z M3 12l9 5 9-5 M3 16l9 5 9-5",
  enrollments: "M5 3h10l4 4v14H5z M14 3v5h5 M8 13h8 M8 17h5",
  installments: "M4 5h16v16H4z M8 3v4 M16 3v4 M4 10h16 M8 14h2 M14 14h2 M8 18h2",
  payments: "M3 5h18v14H3z M3 9h18 M7 15h4",
  overdue: "M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18 M12 7v6 M12 17h.01",
  completed: "M20 11a8 8 0 1 1-5-7 M8 11l4 4 9-11",
  orders: "M4 7h16 M17 4l3 3-3 3 M20 17H4 M7 14l-3 3 3 3",
  redemptions: "M3 8h18v4H3z M5 12v9h14v-9 M12 8v13 M12 8H8a3 3 0 1 1 3-3z M12 8h4a3 3 0 1 0-3-3z",
  refunds: "M4 10V4 M4 4h6 M4 4l4 4a8 8 0 1 1-2 8 M12 10v6 M9 13h6",
  notifications: "M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9 M10 21h4",
  banners: "M3 4h18v16H3z M3 16l5-5 4 4 4-6 5 7 M7 8h.01",
  stores: "M3 10l2-7h14l2 7 M3 10h18v3H3z M5 13v8h14v-8 M9 21v-5h6v5",
  settings: "M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8 M12 2v3 M12 19v3 M2 12h3 M19 12h3 M5 5l2 2 M17 17l2 2 M5 19l2-2 M17 7l2-2",
  users: "M3 5h18v14H3z M9 8a2 2 0 1 0 0 4 2 2 0 0 0 0-4 M6 16c0-3 6-3 6 0 M15 9h3 M15 13h3",
  audit: "M5 3h14v18H5z M8 7h8 M8 11h8 M8 15h5 M8 18h3",
  system: "M3 3h18v7H3z M3 14h18v7H3z M7 6h.01 M7 17h.01 M11 6h6 M11 17h6",
};
const displayLabel = (key: string) => (({ customer_name: "Customer", scheme_name: "Scheme", name: "Name", paid_installments: "Paid installments" } as Record<string, string>)[key] ?? key.replaceAll("_", " ").replace("paise", "").trim());
const tableColumns = (items: Row[]) => Array.from(new Set(items.flatMap(Object.keys)))
  .filter((key) => !/(^id$|^_id$|_id$|_ids$|^gateway_|^provider_|^idempotency|^password|^tokens_|^policy$|^terms$|^replies$|^slides$|^metadata$)/.test(key)
    && items.some((row) => row[key] != null && typeof row[key] !== "object"))
  .sort((a, b) => {
    const priority = ["customer_name", "name", "scheme_name", "email", "phone", "status", "amount_paise", "monthly_amount_paise", "due_date", "created_at"];
    return (priority.includes(a) ? priority.indexOf(a) : 100) - (priority.includes(b) ? priority.indexOf(b) : 100);
  }).slice(0, 8);
const initialScheme = {
  code: "",
  name: "",
  monthly_amount_paise: 50000,
  installment_count: 11,
  benefit_paise: 50000,
  policy: {
    due_rule: "ANNIVERSARY",
    due_day: 1,
    timezone: "Asia/Kolkata",
    advance_payments_allowed: false,
    grace_days: 7,
    late_payments_allowed: true,
    cancellation_allowed: true,
    refund_deduction_paise: 0,
    redemption_valid_days: 365,
    reminder_days: [7, 3, 1, 0],
    joining_opens_at: null,
    joining_closes_at: null,
    terms_text: "",
  },
};
const field = (
  name: string,
  label: string,
  type = "text",
  value: any = "",
  required = true,
) => (
  <label key={name}>
    {label}
    <input
      name={name}
      type={type}
      defaultValue={value ?? ""}
      required={required}
    />
  </label>
);

const renderCell = (key: string, val: any) => {
  if (val == null || val === "") return "—";
  if (key.endsWith("_paise") && typeof val === "number") return money(val);
  if (typeof val === "boolean") return val ? "Yes" : "No";
  if (typeof val === "string" && /(_at|_date)$/.test(key)) {
    const date = new Date(val);
    if (!Number.isNaN(date.getTime())) return new Intl.DateTimeFormat("en-IN", {
      day: "2-digit", month: "short", year: "numeric", timeZone: "Asia/Kolkata",
    }).format(date);
  }
  if (typeof val === "object" && val !== null) return JSON.stringify(val);
  const str = String(val ?? "");
  const upper = str.toUpperCase();
  const knownStatuses: Record<string, string> = {
    ACTIVE: "active",
    COMPLETED: "completed",
    CAPTURED: "captured",
    VERIFIED: "verified",
    RESOLVED: "resolved",
    CONFIGURED: "configured",
    PENDING: "pending",
    PENDING_APPROVAL: "pending",
    DUE: "due",
    OPEN: "open",
    IN_PROGRESS: "in_progress",
    REQUIRES_REVIEW: "requires_review",
    FAILED: "failed",
    OVERDUE: "overdue",
    CLOSED: "closed",
    REJECTED: "rejected",
    CONFIGURATION_REQUIRED: "configuration_required",
  };
  if (knownStatuses[upper]) {
    return <span className={`status-pill ${knownStatuses[upper]}`}>{str}</span>;
  }
  return str;
};

function BannerEditor({ initial, onSave, busy }: { initial?: Row; onSave: (payload: Row) => void; busy: boolean }) {
  const [mode, setMode] = useState(initial?.mode ?? "content");
  const [title, setTitle] = useState(initial?.title ?? "");
  const [body, setBody] = useState(initial?.body ?? "");
  const [active, setActive] = useState(initial?.active ?? true);
  const [slides, setSlides] = useState<Row[]>(initial?.slides ?? []);
  const [reading, setReading] = useState(false);
  const [uploadError, setUploadError] = useState("");
  const [previewIndex, setPreviewIndex] = useState(0);
  const previewSlide = slides[Math.min(previewIndex, Math.max(0, slides.length - 1))];
  const locked = busy || reading;
  const addFiles = async (files: FileList | null) => {
    if (!files?.length) return;
    setUploadError("");
    if (files.length + slides.length > 8) {
      setUploadError("Use at most 8 images. Remove an image before adding more.");
      return;
    }
    setReading(true);
    try {
      const next = await Promise.all(Array.from(files).map((file) => new Promise<Row>((resolve, reject) => {
        if (!["image/jpeg", "image/png", "image/webp"].includes(file.type) || !file.size || file.size > 5 * 1024 * 1024) {
          reject(new Error("Use PNG, JPEG, or WebP files up to 5 MB."));
          return;
        }
        const reader = new FileReader();
        reader.onload = () => resolve({ title: "", body: "", image: String(reader.result) });
        reader.onerror = () => reject(new Error("Could not read image."));
        reader.readAsDataURL(file);
      })));
      setSlides((current) => [...current, ...next]);
    } catch (error) {
      setUploadError((error as Error).message);
    } finally {
      setReading(false);
    }
  };
  return <form onSubmit={(event) => {
    event.preventDefault();
    if (locked) return;
    if (mode === "images" && !slides.length) {
      setUploadError("Add at least one banner image.");
      return;
    }
    if (mode === "content" && !(title.trim() || body.trim())) {
      setUploadError("Enter a title or message.");
      return;
    }
    onSave({ mode, title, body, slides: mode === "images" ? slides : [], active });
  }}>
    <fieldset disabled={locked}><legend>Banner content & publishing</legend>
      <label>Banner type<select value={mode} onChange={(event) => { setMode(event.target.value); setUploadError(""); }}>
        <option value="content">Text content</option><option value="images">Image carousel</option>
      </select></label>
      {mode === "content" ? <>
        <label>Title<input value={title} maxLength={120} onChange={(event) => setTitle(event.target.value)} required={!body} /></label>
        <label>Message<textarea value={body} maxLength={500} onChange={(event) => setBody(event.target.value)} required={!title} /></label>
      </> : <>
        <p>Upload up to 8 PNG, JPEG, or WebP images, up to 5 MB each.</p>
        <label className="upload-area" onDragOver={(event) => event.preventDefault()} onDrop={(event) => {
          event.preventDefault();
          if (!locked) void addFiles(event.dataTransfer.files);
        }}>Choose or drop banner images
        <span>PNG, JPEG or WebP · Up to 5 MB each</span>
        <input aria-label="Banner images" type="file" accept="image/png,image/jpeg,image/webp" multiple disabled={slides.length >= 8} onChange={(event) => {
          void addFiles(event.currentTarget.files);
          event.currentTarget.value = "";
        }} /></label>
        {reading && <p role="status">Reading images...</p>}
        {slides.map((slide, index) => <div className="slide-card" key={index}>
          <img src={slide.image.startsWith("data:") ? slide.image : new URL(slide.image, new URL(baseUrl, window.location.href)).href} alt="Banner preview" style={{ maxWidth: "100%", maxHeight: 120 }} />
          <label>Slide title<input value={slide.title ?? ""} maxLength={120} onChange={(event) => setSlides((items) => items.map((item, i) => i === index ? { ...item, title: event.target.value } : item))} /></label>
          <label>Slide message<input value={slide.body ?? ""} maxLength={500} onChange={(event) => setSlides((items) => items.map((item, i) => i === index ? { ...item, body: event.target.value } : item))} /></label>
          <button type="button" onClick={() => { setSlides((items) => items.filter((_, i) => i !== index)); setUploadError(""); }}>Remove image</button>
        </div>)}
      </>}
      <section className="banner-preview" aria-label="Customer-view preview">
        <small>Customer-view preview</small>
        {mode === "images" ? previewSlide ? <>
          <div className="banner-preview-image">
            <img src={new URL(previewSlide.image, new URL(baseUrl, window.location.href)).href} alt={previewSlide.title || "Banner slide"} />
            {previewSlide.body && <p className="banner-preview-caption">{previewSlide.body}</p>}
          </div>
          {slides.length > 1 && <div className="preview-pagination" aria-label="Preview slides">{slides.map((_, index) => <button key={index} type="button" aria-label={`Preview slide ${index + 1}`} aria-pressed={index === Math.min(previewIndex, slides.length - 1)} onClick={() => setPreviewIndex(index)}>{index + 1}</button>)}</div>}
        </> : <p className="preview-placeholder">Add an image to preview your banner.</p> : <div className="banner-preview-content"><h3>{title || "Your banner title"}</h3><p>{body || "Your message appears here."}</p></div>}
      </section>
      <label><input type="checkbox" checked={active} onChange={(event) => setActive(event.target.checked)} /> Publish banner</label>
    </fieldset>
    {uploadError && <p className="error" role="alert">{uploadError}</p>}
    <button disabled={locked} type="submit">{busy ? "Saving..." : "Save banner"}</button>
  </form>;
}

function App() {
  const [user, setUser] = useState<CurrentUser | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [page, setPage] = useState("dashboard");
  const [rows, setRows] = useState<Row[]>([]);
  const [summary, setSummary] = useState<Row>({});
  const [offset, setOffset] = useState(0);
  const [total, setTotal] = useState(0);
  const [reportGroup, setReportGroup] = useState("day");
  const [busy, setBusy] = useState(false);
  const [dialog, setDialog] = useState<{ kind: string; row?: Row } | null>(
    null,
  );
  const allowed = (permission: string) =>
    !!user &&
    (user.permissions.includes("*") || user.permissions.includes(permission));
  const selectUser = (value: CurrentUser) => {
    setUser(value);
    setPage(
      Object.keys(permissions).find(
        (p) =>
          value.permissions.includes("*") ||
          value.permissions.includes(permissions[p]),
      ) ?? "customers",
    );
  };
  useEffect(() => {
    api
      .me()
      .then(selectUser)
      .catch(() => undefined)
      .finally(() => setLoading(false));
  }, []);
  async function load() {
    setLoading(true);
    setError("");
    setRows([]);
    try {
      if (page === "dashboard")
        setSummary(await api.request("/admin/reports/summary"));
      else if (page === "system") {
        const status = await api.request("/admin/system/status");
        setRows(
          Object.entries(status).map(([service, ready]) => ({
            service: service.replaceAll("_", " "),
            status: ready ? "Configured" : "Configuration required",
          })),
        );
        setTotal(0);
      } else if (page === "reports") {
        setRows(
          await api.request(`/admin/reports/collections?group=${reportGroup}`),
        );
        setTotal(0);
      } else {
        const data = await api.request(
          `/admin/resources/${page}?skip=${offset}&limit=25`,
        );
        setRows(data.items);
        setTotal(data.total);
      }
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setLoading(false);
    }
  }
  useEffect(() => {
    if (user) void load();
  }, [user, page, offset, reportGroup]);
  async function action(fn: () => Promise<unknown>) {
    setBusy(true);
    setError("");
    setNotice("");
    try {
      await fn();
      setNotice("Saved successfully.");
      setDialog(null);
      await load();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }
  async function login(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    setBusy(true);
    setError("");
    try {
      selectUser(
        await api.login(
          String(form.get("email")),
          String(form.get("password")),
        ),
      );
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    const values = Object.fromEntries(form.entries());
    const row = dialog?.row;
    const kind = dialog?.kind;
    await action(async () => {
      if (kind === "scheme") {
        const payload = {
          code: values.code,
          name: values.name,
          monthly_amount_paise: Math.round(Number(values.monthly) * 100),
          installment_count: Number(values.count),
          benefit_paise: Math.round(Number(values.benefit) * 100),
          policy: {
            due_rule: values.due_rule,
            due_day: Number(values.due_day),
            timezone: values.timezone,
            advance_payments_allowed: values.advance === "on",
            grace_days: Number(values.grace),
            late_payments_allowed: values.late === "on",
            cancellation_allowed: values.cancellation === "on",
            refund_deduction_paise: Math.round(Number(values.deduction) * 100),
            redemption_valid_days: Number(values.valid_days),
            reminder_days: String(values.reminders).split(",").map(Number),
            joining_opens_at: values.opens
              ? new Date(String(values.opens)).toISOString()
              : null,
            joining_closes_at: values.closes
              ? new Date(String(values.closes)).toISOString()
              : null,
            terms_text: values.terms,
          },
        };
        await api.request("/schemes" + (row ? "/" + row.id : ""), {
          method: row ? "PUT" : "POST",
          body: JSON.stringify(payload),
        });
      } else if (kind === "store")
        await api.request("/admin/stores" + (row ? "/" + row.id : ""), {
          method: row ? "PUT" : "POST",
          body: JSON.stringify({ ...values, active: values.active === "on" }),
        });
      else if (kind === "notification")
        await api.request("/admin/notifications", {
          method: "POST",
          body: JSON.stringify(values),
        });
      else if (kind === "staff")
        await api.request("/admin/users", {
          method: "POST",
          body: JSON.stringify(values),
        });
      else if (kind === "staff_access")
        await api.request(`/admin/users/${row?.id}`, {
          method: "PATCH",
          body: JSON.stringify({
            role: values.role,
            is_active: values.is_active === "on",
          }),
        });
      else if (kind === "edit_customer")
        await api.request(`/admin/customers/${row?.id}`, {
          method: "PATCH",
          body: JSON.stringify({
            name: String(values.name).trim(),
            email: String(values.email).trim(),
            phone: String(values.phone).trim(),
          }),
        });
      else if (kind === "kyc_review")
        await api.request(`/admin/kyc/${row?.user_id}/review`, {
          method: "PATCH",
          body: JSON.stringify(values),
        });
      else if (kind === "support")
        await api.request(`/admin/support/${row?.id}`, {
          method: "PATCH",
          body: JSON.stringify(values),
        });
      else if (kind === "refund")
        await api.request(`/admin/refunds/${row?.id}/decision`, {
          method: "POST",
          body: JSON.stringify({
            approved: values.decision === "approve",
            reason: values.reason,
          }),
        });
      else if (kind === "redemption")
        await api.request(`/admin/redemptions/${row?.id}/complete`, {
          method: "POST",
          body: JSON.stringify({
            ...values,
            invoice_value_paise: Math.round(Number(values.invoice_value) * 100),
            invoice_value: undefined,
          }),
        });
      else if (kind === "content")
        await api.request(`/admin/content/${values.key}`, {
          method: "PUT",
          body: JSON.stringify({
            title: values.title,
            body: values.body,
            active: values.active === "on",
          }),
        });
    });
  }
  if (!user)
    return (
      <div className="login-wrapper">
        <main className="login">
          <div className="login-brand">
            <div className="login-brand-icon">A2</div>
            <div>
              <h1>A2Mobile</h1>
              <p style={{ margin: 0, fontSize: "13px" }}>Scheme Administration Portal</p>
            </div>
          </div>
          {error && (
            <p role="alert" className="error">
              {error}
            </p>
          )}
          <form onSubmit={login}>
            {field("email", "Email address", "email")}
            {field("password", "Password", "password")}
            <button disabled={busy || loading} className="primary-btn">
              {busy ? "Signing in…" : "Sign in"}
            </button>
          </form>
        </main>
      </div>
    );
  const scheme = dialog?.row ?? initialScheme;
  const policy = scheme.policy ?? initialScheme.policy;
  const columns = tableColumns(rows);
  return (
    <div className="app">
      <aside>
        <div className="brand-header">
          <div className="brand-icon">A2</div>
          <div>
            <h2>A2Mobile</h2>
            <div className="role-badge">{user.role.replaceAll("_", " ")}</div>
          </div>
        </div>
        <nav>
          {navigationGroups.map((group) => {
            const pages = group.pages.filter((p) => allowed(permissions[p]));
            return pages.length > 0 && <section className="nav-group" key={group.label}>
            <h3>{group.label}</h3>
            {pages.map((p) => (
              <button
                key={p}
                className={page === p ? "selected" : ""}
                aria-current={page === p ? "page" : undefined}
                onClick={() => {
                  setPage(p);
                  setOffset(0);
                  setNotice("");
                }}
              >
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d={navigationIcons[p]} /></svg>{names[p]}
              </button>
            ))}</section>;
          })}
        </nav>
        <button
          className="signout-btn"
          onClick={() => {
            void api.logout().finally(() => setUser(null));
          }}
        >
          Sign out
        </button>
      </aside>
      <main>
        <header>
          <div className="header-title-wrap">
            <h1>{names[page]}</h1>
            <div className="header-user-badge">
              <span>●</span>
              <span>{user.email}</span>
            </div>
          </div>
          <div className="header-actions">
            <button disabled={loading} onClick={() => void load()}>
              Refresh
            </button>
          </div>
        </header>
        {error && (
          <p role="alert" className="error">
            {error}
          </p>
        )}
        {notice && (
          <p role="status" className="notice">
            {notice}
          </p>
        )}
        <div className="toolbar">
          {!["dashboard", "reports", "system"].includes(page) && (
            <button
              disabled={loading || !rows.length}
              onClick={() => exportCsv(rows, `${page}-${offset + 1}.csv`)}
            >
              Export this page
            </button>
          )}
          {page === "schemes" && (
            <button className="primary-btn" onClick={() => setDialog({ kind: "scheme" })}>
              Create draft scheme
            </button>
          )}
          {page === "stores" && (
            <button className="primary-btn" onClick={() => setDialog({ kind: "store" })}>
              Add store
            </button>
          )}
          {page === "notifications" && (
            <button className="primary-btn" onClick={() => setDialog({ kind: "notification" })}>
              Send notification
            </button>
          )}
          {page === "users" && (
            <button className="primary-btn" onClick={() => setDialog({ kind: "staff" })}>
              Create staff account
            </button>
          )}
          {page === "banners" && !rows.length && (
            <button className="primary-btn" disabled={loading || busy} onClick={() => setDialog({ kind: "banner" })}>Add banner</button>
          )}
          {page === "overdue" && allowed("reconciliation:manage") && (
            <button
              disabled={busy}
              onClick={() =>
                void action(() =>
                  api.request("/admin/jobs/refresh-lifecycle", {
                    method: "POST",
                  }),
                )
              }
            >
              Refresh due status
            </button>
          )}
          {page === "reports" && (
            <>
              <select
                aria-label="Report grouping"
                value={reportGroup}
                onChange={(e) => setReportGroup(e.target.value)}
              >
                {["day", "month", "scheme", "customer"].map((x) => (
                  <option key={x}>{x}</option>
                ))}
              </select>
              <button
                disabled={loading || !rows.length}
                onClick={() =>
                  exportCsv(rows, `collections-${reportGroup}.csv`)
                }
              >
                Export CSV
              </button>
              <span>Up to 1,000 groups, newest first.</span>
            </>
          )}
        </div>
        {loading ? (
          <p>Loading…</p>
        ) : page === "dashboard" ? (
          <>
          <div className="metrics">
            {Object.entries(summary).filter(([key]) => dashboardPrimary.includes(key))
              .sort(([a], [b]) => dashboardPrimary.indexOf(a) - dashboardPrimary.indexOf(b))
              .map(([key, value]) => <DashboardMetric key={key} name={key} value={value} />)}
          </div>
          <DashboardCharts api={api} summary={summary} canViewEnrollments={allowed("enrollment:read")}
            onNavigate={(destination) => { setPage(destination); setOffset(0); setNotice(""); }} />
          <details className="dashboard-more"><summary>More dashboard figures</summary><div className="metrics">
            {Object.entries(summary).filter(([key]) => !dashboardPrimary.includes(key)).map(([key, value]) => <DashboardMetric key={key} name={key} value={value} />)}
          </div></details>
          </>
        ) : rows.length === 0 ? (
          <p>No records found.</p>
        ) : (
          <div className="table">
            <table>
              <thead>
                <tr>
                  {columns.map((key) => (
                    <th key={key} className={key.endsWith("_paise") ? "currency" : ""}>
                      {displayLabel(key)}
                    </th>
                  ))}
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((row, i) => (
                  <tr key={row.id ?? i}>
                    {columns.map((key) => (
                      <td key={key} className={key.endsWith("_paise") ? "currency" : ""}>
                        {renderCell(key, row[key])}
                      </td>
                    ))}
                    <td className="actions">
                      <div className="row-actions">
                      <RowAction icon="view" label="View details" onClick={() => setDialog({ kind: "details", row })} />
                      {page === "customers" && allowed("customer:manage") && (
                        <RowAction icon="edit" label="Edit customer" disabled={busy} onClick={() => setDialog({kind: "edit_customer", row})} />
                      )}
                      {page === "customers" && allowed("customer:manage") && (
                        <RowAction icon="power" label={row.is_active ? "Deactivate customer" : "Activate customer"} tone={row.is_active ? "danger" : "success"}
                          disabled={busy}
                          onClick={() => {
                            if (
                              confirm(
                                `${row.is_active ? "Deactivate" : "Activate"} this customer account?`,
                              )
                            )
                              void action(() =>
                                api.request(`/admin/customers/${row.id}`, {
                                  method: "PATCH",
                                  body: JSON.stringify({
                                    is_active: !row.is_active,
                                  }),
                                }),
                              );
                          }}
                        />
                      )}
                      {page === "users" && row.id !== user.id && (
                        <RowAction icon="access" label="Change access"
                          onClick={() =>
                            setDialog({ kind: "staff_access", row })
                          }
                        />
                      )}
                      {page === "stores" && (
                        <RowAction icon="edit" label="Edit store"
                          onClick={() => setDialog({ kind: "store", row })}
                        />
                      )}
                      {page === "kyc" && (
                        <RowAction icon="review" label="Review KYC"
                          onClick={() => setDialog({ kind: "kyc_review", row })}
                        />
                      )}
                      {["settings", "banners"].includes(page) && (
                        <RowAction icon="edit" label={page === "banners" || row.id === "banner" ? "Edit banner" : "Edit content"}
                          onClick={() => setDialog({ kind: page === "banners" || row.id === "banner" ? "banner" : "content", row })}
                        />
                      )}
                      {page === "orders" && !row.gateway_order_id && (
                        <RowAction icon="refresh" label="Recover gateway order"
                          disabled={busy}
                          onClick={() =>
                            void action(() =>
                              api.request(
                                `/admin/payments/orders/${row.id}/recover`,
                                { method: "POST" },
                              ),
                            )
                          }
                        />
                      )}
                      {page === "schemes" && (
                        <>
                          <RowAction icon="edit" label="Revise scheme"
                            onClick={() => setDialog({ kind: "scheme", row })}
                          />
                          <RowAction icon={row.active ? "unpublish" : "publish"} label={row.active ? "Unpublish scheme" : "Publish scheme"} tone={row.active ? "danger" : "success"}
                            disabled={busy}
                            onClick={() => {
                              if (
                                confirm(
                                  row.active
                                    ? "Stop new enrollments for this scheme?"
                                    : "Publish this version and its reviewed terms?",
                                )
                              )
                                void action(() =>
                                  api.request(
                                    `/schemes/${row.id}/publication`,
                                    {
                                      method: "PATCH",
                                      body: JSON.stringify({
                                        active: !row.active,
                                        reviewed_version: row.version,
                                      }),
                                    },
                                  ),
                                );
                            }}
                          />
                        </>
                      )}
                      {page === "orders" && row.gateway_order_id && (
                        <RowAction icon="refresh" label="Reconcile payment"
                          disabled={busy}
                          onClick={() =>
                            void action(() =>
                              api.request(
                                `/admin/payments/${row.gateway_order_id}/reconcile`,
                                { method: "POST" },
                              ),
                            )
                          }
                        />
                      )}
                      {page === "support" && (
                        <RowAction icon="reply" label="Reply to ticket"
                          onClick={() => setDialog({ kind: "support", row })}
                        />
                      )}
                      {page === "refunds" &&
                        allowed("refund:manage") &&
                        row.status === "PENDING_APPROVAL" && (
                          <RowAction icon="review" label="Review refund"
                            onClick={() => setDialog({ kind: "refund", row })}
                          />
                        )}
                      {page === "refunds" &&
                        allowed("refund:manage") &&
                        ["APPROVED", "PROCESSING"].includes(row.status) && (
                          <RowAction icon="refund" label="Execute refund" tone="danger"
                            disabled={busy}
                            onClick={() => {
                              if (
                                confirm(
                                  `Send the approved refund of ${money(row.amount_paise)} through Razorpay?`,
                                )
                              )
                                void action(() =>
                                  api.request(
                                    `/admin/refunds/${row.id}/execute`,
                                    { method: "POST" },
                                  ),
                                );
                            }}
                          />
                        )}
                      {page === "redemptions" && row.status === "PENDING" && (
                        <RowAction icon="redeem" label="Complete redemption"
                          onClick={() => setDialog({ kind: "redemption", row })}
                        />
                      )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        {total > 25 && (
          <div className="toolbar">
            <button
              disabled={offset === 0}
              onClick={() => setOffset(offset - 25)}
            >
              Previous
            </button>
            <span>
              {offset + 1}–{Math.min(offset + 25, total)} of {total}
            </span>
            <button
              disabled={offset + 25 >= total}
              onClick={() => setOffset(offset + 25)}
            >
              Next
            </button>
          </div>
        )}
        {dialog && (
          <div className="overlay">
            <section className="dialog" role="dialog" aria-modal="true" aria-labelledby="dialog-title">
              <header>
                <h2 id="dialog-title">
                  {({ scheme: "Scheme terms", edit_customer: "Edit customer", store: "Store details", notification: "Send notification", staff: "Create staff account", staff_access: "Staff access", kyc_review: "KYC review", support: "Support response", refund: "Refund review", redemption: "Complete redemption", content: "Published content", banner: "Banner editor", details: "Record details" } as Record<string, string>)[dialog.kind] ?? "Record"}
                </h2>
                <button onClick={() => setDialog(null)}>Close</button>
              </header>
              {error && <p className="error">{error}</p>}
              {dialog.kind === "details" ? (
                <dl>
                  {Object.entries(dialog.row ?? {}).map(([key, value]) => (
                    <div key={key}>
                      <dt>{key.replaceAll("_", " ")}</dt>
                      <dd>
                        {typeof value === "object" ? (
                          <pre>{JSON.stringify(value, null, 2)}</pre>
                        ) : (
                          String(value)
                        )}
                      </dd>
                    </div>
                  ))}
                </dl>
              ) : dialog.kind === "banner" ? (
                <BannerEditor
                  initial={dialog.row}
                  busy={busy}
                  onSave={(payload) => void action(() => api.request("/admin/banner", {
                    method: "PUT",
                    body: JSON.stringify(payload),
                  }))}
                />
              ) : (
                <form onSubmit={submit}>
                  {dialog.kind === "scheme" && (
                    <>
                      <fieldset className="form-grid"><legend>Scheme details</legend>
                      {field("code", "Scheme code", "text", scheme.code)}
                      {field("name", "Name", "text", scheme.name)}
                      {field(
                        "monthly",
                        "Monthly contribution (INR)",
                        "number",
                        scheme.monthly_amount_paise / 100,
                      )}
                      {field(
                        "count",
                        "Number of installments",
                        "number",
                        scheme.installment_count,
                      )}
                      {field(
                        "benefit",
                        "Shop benefit (INR)",
                        "number",
                        scheme.benefit_paise / 100,
                      )}
                      </fieldset>
                      <fieldset className="form-grid"><legend>Payment schedule</legend>
                      <label>
                        Due-date rule
                        <select name="due_rule" defaultValue={policy.due_rule}>
                          <option value="ANNIVERSARY">
                            Joining-day anniversary
                          </option>
                          <option value="FIXED_DAY">Fixed day of month</option>
                        </select>
                      </label>
                      {field(
                        "due_day",
                        "Fixed day (1–28)",
                        "number",
                        policy.due_day,
                      )}
                      <label>
                        Calendar timezone
                        <select
                          name="timezone"
                          defaultValue={policy.timezone ?? "Asia/Kolkata"}
                        >
                          <option>Asia/Kolkata</option>
                          <option>UTC</option>
                        </select>
                      </label>
                      <label>
                        <input
                          type="checkbox"
                          name="advance"
                          defaultChecked={
                            policy.advance_payments_allowed ?? false
                          }
                        />
                        Allow advance contributions (benefit still waits for the
                        final due date)
                      </label>
                      {field(
                        "grace",
                        "Grace period (days)",
                        "number",
                        policy.grace_days,
                      )}
                      <label>
                        <input
                          type="checkbox"
                          name="late"
                          defaultChecked={policy.late_payments_allowed}
                        />
                        Allow late payments
                      </label>
                      </fieldset>
                      <fieldset className="form-grid"><legend>Cancellation & redemption</legend>
                      <label>
                        <input
                          type="checkbox"
                          name="cancellation"
                          defaultChecked={policy.cancellation_allowed}
                        />
                        Allow cancellation requests
                      </label>
                      {field(
                        "deduction",
                        "Refund deduction (INR)",
                        "number",
                        policy.refund_deduction_paise / 100,
                      )}
                      {field(
                        "valid_days",
                        "Redemption validity (days)",
                        "number",
                        policy.redemption_valid_days,
                      )}
                      </fieldset>
                      <fieldset className="form-grid"><legend>Enrollment & customer terms</legend>
                      {field(
                        "reminders",
                        "Reminder days before due date, separated by commas",
                        "text",
                        policy.reminder_days.join(","),
                      )}
                      {field(
                        "opens",
                        "Joining opens (optional)",
                        "datetime-local",
                        policy.joining_opens_at?.slice(0, 16),
                        false,
                      )}
                      {field(
                        "closes",
                        "Joining closes (optional)",
                        "datetime-local",
                        policy.joining_closes_at?.slice(0, 16),
                        false,
                      )}
                      <label>
                        Customer-facing terms
                        <textarea
                          name="terms"
                          required
                          minLength={20}
                          defaultValue={policy.terms_text}
                        />
                      </label>
                      </fieldset>
                      <p>
                        Changes are saved as a draft. Existing enrollment terms
                        stay unchanged.
                      </p>
                    </>
                  )}
                  {dialog.kind === "edit_customer" && (
                    <fieldset className="form-grid"><legend>Customer contact details</legend>
                      {error && <p role="alert">{error}</p>}
                      <label>Full name<input name="name" required minLength={2} maxLength={120} defaultValue={dialog.row?.name ?? ""} /></label>
                      <label>Email<input name="email" type="email" required defaultValue={dialog.row?.email ?? ""} /></label>
                      <label>Phone with country code<input name="phone" type="tel" required pattern={"\\+[1-9][0-9]{7,14}"} title="Use + and country code followed by digits only, for example +919876543210" defaultValue={dialog.row?.phone ?? ""} /></label>
                      <p>Changing email or phone requires that contact to be verified again and signs out the customer's existing sessions.</p>
                    </fieldset>
                  )}
                  {dialog.kind === "store" && (
                    <fieldset className="form-grid"><legend>Store details & availability</legend>
                      {field("name", "Store name", "text", dialog.row?.name)}
                      {field("address", "Address", "text", dialog.row?.address)}
                      {field(
                        "phone",
                        "Phone with country code",
                        "tel",
                        dialog.row?.phone,
                      )}
                      <label>
                        <input
                          type="checkbox"
                          name="active"
                          defaultChecked={dialog.row?.active ?? true}
                        />
                        Active store
                      </label>
                    </fieldset>
                  )}
                  {dialog.kind === "notification" && (
                    <fieldset><legend>Recipient & message</legend>
                      {field("user_id", "Customer ID")}
                      {field("title", "Title")}
                      <label>
                        Message
                        <textarea name="body" required />
                      </label>
                    </fieldset>
                  )}
                  {["staff", "staff_access"].includes(dialog.kind) && (
                    <>
                      {dialog.kind === "staff" && (
                        <fieldset><legend>Account credentials</legend>
                          {field("email", "Email", "email")}
                          {field(
                            "password",
                            "Initial password (8+ characters; letters, number, special character)",
                            "password",
                          )}
                        </fieldset>
                      )}
                      <fieldset><legend>Role & access</legend>
                      {dialog.kind === "staff_access" && (
                        <label>
                          <input
                            type="checkbox"
                            name="is_active"
                            defaultChecked={dialog.row?.is_active}
                          />
                          Account active
                        </label>
                      )}
                      <label>
                        Role
                        <select
                          name="role"
                          defaultValue={dialog.row?.role ?? "store_staff"}
                        >
                          {[
                            "store_staff",
                            "accountant",
                            "admin",
                            "super_admin",
                          ].map((x) => (
                            <option key={x}>{x}</option>
                          ))}
                        </select>
                      </label>
                      </fieldset>
                    </>
                  )}
                  {dialog.kind === "kyc_review" && (
                    <fieldset><legend>Verification decision</legend>
                      <p>
                        Identity approval requires a successful provider
                        verification.
                      </p>
                      <label>
                        Status
                        <select name="status">
                          <option value="REQUIRES_REVIEW">Needs review</option>
                          <option value="FAILED">Rejected</option>
                        </select>
                      </label>
                      <label>
                        Reason
                        <textarea name="reason" required minLength={5} />
                      </label>
                    </fieldset>
                  )}
                  {dialog.kind === "support" && (
                    <fieldset><legend>Response & ticket status</legend>
                      <label>
                        Reply
                        <textarea name="message" required />
                      </label>
                      <label>
                        Status
                        <select name="status" defaultValue={dialog.row?.status}>
                          {["OPEN", "IN_PROGRESS", "RESOLVED", "CLOSED"].map(
                            (x) => (
                              <option key={x}>{x}</option>
                            ),
                          )}
                        </select>
                      </label>
                    </fieldset>
                  )}
                  {dialog.kind === "refund" && (
                    <fieldset><legend>Refund review</legend>
                      <p>Eligible refund: {money(dialog.row?.amount_paise)}</p>
                      <label>
                        Decision
                        <select name="decision">
                          <option value="approve">Approve</option>
                          <option value="reject">Reject</option>
                        </select>
                      </label>
                      <label>
                        Reason
                        <textarea name="reason" required minLength={5} />
                      </label>
                    </fieldset>
                  )}
                  {dialog.kind === "redemption" && (
                    <>
                      <p>
                        Eligible value:{" "}
                        {money(dialog.row?.eligible_value_paise)}
                      </p>
                      <fieldset className="form-grid"><legend>Customer verification & store</legend>
                      {field("otp", "Fresh customer redemption code")}
                      {field("store_id", "Store ID")}
                      </fieldset>
                      <fieldset className="form-grid"><legend>Purchase details</legend>
                      {field("invoice_reference", "Invoice reference")}
                      {field("product_reference", "Product reference")}
                      {field("invoice_value", "Invoice value (INR)", "number")}
                      </fieldset>
                    </>
                  )}
                  {dialog.kind === "content" && (
                    <fieldset><legend>Published customer content</legend>
                      <label>
                        Content
                        <select
                          name="key"
                          defaultValue={
                            dialog.row?.id ??
                            "faq"
                          }
                        >
                          {["faq", "terms", "privacy", "contact"].map(
                            (x) => (
                              <option key={x}>{x}</option>
                            ),
                          )}
                        </select>
                      </label>
                      {field("title", "Title", "text", dialog.row?.title)}
                      <label>
                        Content
                        <textarea
                          name="body"
                          required
                          defaultValue={dialog.row?.body}
                        />
                      </label>
                      <label>
                        <input
                          type="checkbox"
                          name="active"
                          defaultChecked={dialog.row?.active ?? true}
                        />
                        Publish
                      </label>
                    </fieldset>
                  )}
                  <button disabled={busy} type="submit">
                    {busy ? "Saving…" : "Save"}
                  </button>
                </form>
              )}
            </section>
          </div>
        )}
      </main>
    </div>
  );
}
createRoot(document.getElementById("root")!).render(<App />);
