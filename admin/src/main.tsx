/// <reference types="vite/client" />
import { FormEvent, useEffect, useState } from "react";
import { createRoot } from "react-dom/client";
import { ApiClient, CurrentUser } from "./api";
import { exportCsv } from "./csv";
import "./styles.css";

type Row = Record<string, any>;
const api = new ApiClient();
const money = (n: number) =>
  new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR" }).format(
    n / 100,
  );
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
  if (key.endsWith("_paise") && typeof val === "number") return money(val);
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
  const columns = Array.from(new Set(rows.flatMap((row) => Object.keys(row))))
    .filter(
      (key) =>
        ![
          "id",
          "_id",
          "policy",
          "terms",
          "idempotency_key",
          "replies",
          "gateway_refunds",
        ].includes(key),
    )
    .slice(0, 9);
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
          {Object.keys(names)
            .filter((p) => allowed(permissions[p]))
            .map((p) => (
              <button
                key={p}
                className={page === p ? "selected" : ""}
                onClick={() => {
                  setPage(p);
                  setOffset(0);
                  setNotice("");
                }}
              >
                {names[p]}
              </button>
            ))}
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
            <button onClick={() => setDialog({ kind: "scheme" })}>
              Create draft scheme
            </button>
          )}
          {page === "stores" && (
            <button onClick={() => setDialog({ kind: "store" })}>
              Add store
            </button>
          )}
          {page === "notifications" && (
            <button onClick={() => setDialog({ kind: "notification" })}>
              Send notification
            </button>
          )}
          {page === "users" && (
            <button onClick={() => setDialog({ kind: "staff" })}>
              Create staff account
            </button>
          )}
          {["settings", "banners"].includes(page) && (
            <button onClick={() => setDialog({ kind: "content" })}>
              Edit published content
            </button>
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
          <div className="metrics">
            {Object.entries(summary).map(([key, value]) => (
              <article key={key}>
                <span>{key.replaceAll("_", " ").replace("paise", "")}</span>
                <strong>{key.endsWith("_paise") ? money(value) : value}</strong>
              </article>
            ))}
          </div>
        ) : rows.length === 0 ? (
          <p>No records found.</p>
        ) : (
          <div className="table">
            <table>
              <thead>
                <tr>
                  {columns.map((key) => (
                    <th key={key}>
                      {key.replaceAll("_", " ").replace("paise", "")}
                    </th>
                  ))}
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((row, i) => (
                  <tr key={row.id ?? i}>
                    {columns.map((key) => (
                      <td key={key}>
                        {renderCell(key, row[key])}
                      </td>
                    ))}
                    <td className="actions">
                      {page === "customers" && allowed("customer:manage") && (
                        <button disabled={busy} onClick={() => setDialog({kind: "edit_customer", row})}>Edit customer</button>
                      )}
                      {page === "customers" && allowed("customer:manage") && (
                        <button
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
                        >
                          {row.is_active ? "Deactivate" : "Activate"}
                        </button>
                      )}
                      {page === "users" && row.id !== user.id && (
                        <button
                          onClick={() =>
                            setDialog({ kind: "staff_access", row })
                          }
                        >
                          Change access
                        </button>
                      )}
                      {page === "stores" && (
                        <button
                          onClick={() => setDialog({ kind: "store", row })}
                        >
                          Edit store
                        </button>
                      )}
                      {page === "kyc" && (
                        <button
                          onClick={() => setDialog({ kind: "kyc_review", row })}
                        >
                          Review
                        </button>
                      )}
                      {["settings", "banners"].includes(page) && (
                        <button
                          onClick={() => setDialog({ kind: "content", row })}
                        >
                          Edit content
                        </button>
                      )}
                      {page === "orders" && !row.gateway_order_id && (
                        <button
                          disabled={busy}
                          onClick={() =>
                            void action(() =>
                              api.request(
                                `/admin/payments/orders/${row.id}/recover`,
                                { method: "POST" },
                              ),
                            )
                          }
                        >
                          Recover gateway order
                        </button>
                      )}
                      <button
                        onClick={() => setDialog({ kind: "details", row })}
                      >
                        Details
                      </button>
                      {page === "schemes" && (
                        <>
                          <button
                            onClick={() => setDialog({ kind: "scheme", row })}
                          >
                            Revise
                          </button>
                          <button
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
                          >
                            {row.active ? "Unpublish" : "Publish"}
                          </button>
                        </>
                      )}
                      {page === "orders" && row.gateway_order_id && (
                        <button
                          disabled={busy}
                          onClick={() =>
                            void action(() =>
                              api.request(
                                `/admin/payments/${row.gateway_order_id}/reconcile`,
                                { method: "POST" },
                              ),
                            )
                          }
                        >
                          Reconcile
                        </button>
                      )}
                      {page === "support" && (
                        <button
                          onClick={() => setDialog({ kind: "support", row })}
                        >
                          Reply
                        </button>
                      )}
                      {page === "refunds" &&
                        allowed("refund:manage") &&
                        row.status === "PENDING_APPROVAL" && (
                          <button
                            onClick={() => setDialog({ kind: "refund", row })}
                          >
                            Review
                          </button>
                        )}
                      {page === "refunds" &&
                        allowed("refund:manage") &&
                        ["APPROVED", "PROCESSING"].includes(row.status) && (
                          <button
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
                          >
                            Execute refund
                          </button>
                        )}
                      {page === "redemptions" && row.status === "PENDING" && (
                        <button
                          onClick={() => setDialog({ kind: "redemption", row })}
                        >
                          Complete redemption
                        </button>
                      )}
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
            <section className="dialog" role="dialog" aria-modal="true">
              <header>
                <h2>
                  {dialog.kind === "scheme"
                    ? "Scheme terms"
                    : dialog.kind.replaceAll("_", " ")}
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
              ) : (
                <form onSubmit={submit}>
                  {dialog.kind === "scheme" && (
                    <>
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
                      <p>
                        Changes are saved as a draft. Existing enrollment terms
                        stay unchanged.
                      </p>
                    </>
                  )}
                  {dialog.kind === "edit_customer" && (
                    <>
                      {error && <p role="alert">{error}</p>}
                      <label>Full name<input name="name" required minLength={2} maxLength={120} defaultValue={dialog.row?.name ?? ""} /></label>
                      <label>Email<input name="email" type="email" required defaultValue={dialog.row?.email ?? ""} /></label>
                      <label>Phone with country code<input name="phone" type="tel" required pattern={"\\+[1-9][0-9]{7,14}"} title="Use + and country code followed by digits only, for example +919876543210" defaultValue={dialog.row?.phone ?? ""} /></label>
                      <p>Changing email or phone requires that contact to be verified again and signs out the customer's existing sessions.</p>
                    </>
                  )}
                  {dialog.kind === "store" && (
                    <>
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
                    </>
                  )}
                  {dialog.kind === "notification" && (
                    <>
                      {field("user_id", "Customer ID")}
                      {field("title", "Title")}
                      <label>
                        Message
                        <textarea name="body" required />
                      </label>
                    </>
                  )}
                  {["staff", "staff_access"].includes(dialog.kind) && (
                    <>
                      {dialog.kind === "staff" && (
                        <>
                          {field("email", "Email", "email")}
                          {field(
                            "password",
                            "Initial password (12+ characters)",
                            "password",
                          )}
                        </>
                      )}
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
                    </>
                  )}
                  {dialog.kind === "kyc_review" && (
                    <>
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
                    </>
                  )}
                  {dialog.kind === "support" && (
                    <>
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
                    </>
                  )}
                  {dialog.kind === "refund" && (
                    <>
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
                    </>
                  )}
                  {dialog.kind === "redemption" && (
                    <>
                      <p>
                        Eligible value:{" "}
                        {money(dialog.row?.eligible_value_paise)}
                      </p>
                      {field("otp", "Fresh customer redemption code")}
                      {field("store_id", "Store ID")}
                      {field("invoice_reference", "Invoice reference")}
                      {field("product_reference", "Product reference")}
                      {field("invoice_value", "Invoice value (INR)", "number")}
                    </>
                  )}
                  {dialog.kind === "content" && (
                    <>
                      <label>
                        Content
                        <select
                          name="key"
                          defaultValue={
                            dialog.row?.id ??
                            (page === "banners" ? "banner" : "faq")
                          }
                        >
                          {["faq", "terms", "privacy", "contact", "banner"].map(
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
                    </>
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
