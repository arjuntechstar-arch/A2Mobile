import { beforeEach, expect, test, vi } from "vitest";
import { ApiClient } from "./api";
import { csvText } from "./csv";

const storage = new Map<string, string>();
beforeEach(() => {
  storage.clear();
  vi.stubGlobal("sessionStorage", {
    getItem: (key: string) => storage.get(key) ?? null,
    setItem: (key: string, value: string) => storage.set(key, value),
    removeItem: (key: string) => storage.delete(key),
  });
});
const response = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), { status });

test("customer login revokes and removes the staff portal session", async () => {
  const fetch = vi
    .fn()
    .mockResolvedValueOnce(
      response({ access_token: "access", refresh_token: "refresh" }),
    )
    .mockResolvedValueOnce(response({ role: "customer" }))
    .mockResolvedValueOnce(response({ status: "logged_out" }));
  vi.stubGlobal("fetch", fetch);
  await expect(
    new ApiClient().login("customer@example.com", "password"),
  ).rejects.toThrow("customer app");
  expect(fetch.mock.calls[2][0]).toMatch(/auth\/logout$/);
  expect(storage.has("scheme_tokens")).toBe(false);
});

test("parallel expired requests share a single refresh and use rotated access", async () => {
  storage.set(
    "scheme_tokens",
    JSON.stringify({ access_token: "old", refresh_token: "refresh" }),
  );
  let refreshes = 0;
  vi.stubGlobal(
    "fetch",
    vi.fn(async (url: string, init: RequestInit) => {
      if (url.endsWith("/auth/refresh")) {
        refreshes++;
        await new Promise((resolve) => setTimeout(resolve, 20));
        return response({ access_token: "new", refresh_token: "rotated" });
      }
      return (init.headers as Record<string, string>).Authorization ===
        "Bearer new"
        ? response({ ok: true })
        : response({ detail: "Expired" }, 401);
    }),
  );
  const client = new ApiClient();
  expect(
    await Promise.all([client.request("/one"), client.request("/two")]),
  ).toEqual([{ ok: true }, { ok: true }]);
  expect(refreshes).toBe(1);
  expect(JSON.parse(storage.get("scheme_tokens")!).refresh_token).toBe(
    "rotated",
  );
});

test("CSV escapes quotes and neutralizes spreadsheet formulas", () => {
  const csv = csvText([
    { name: '=HYPERLINK("https://invalid")', note: "first, second\nthird" },
  ]);
  expect(csv).toContain('"\'=HYPERLINK(""https://invalid"")"');
  expect(csv).toContain('"first, second\nthird"');
});
