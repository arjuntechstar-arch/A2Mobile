export type CurrentUser = {
  id: string;
  email: string;
  role: string;
  permissions: string[];
};
type Tokens = { access_token: string; refresh_token: string };
export const baseUrl =
  import.meta.env.VITE_API_BASE_URL ?? "http://localhost:8000/api";
export class ApiClient {
  private tokens: Tokens | null = (() => {
    try {
      return JSON.parse(sessionStorage.getItem("scheme_tokens") ?? "null");
    } catch {
      return null;
    }
  })();
  private refreshing: Promise<boolean> | null = null;
  async login(email: string, password: string): Promise<CurrentUser> {
    this.tokens = await this.request(
      "/auth/login",
      { method: "POST", body: JSON.stringify({ email, password }) },
      false,
    );
    this.save();
    const user: CurrentUser = await this.request("/auth/me");
    if (user.role === "customer") {
      await this.logout();
      throw new Error("Use the customer app for this account.");
    }
    return user;
  }
  async me(): Promise<CurrentUser> {
    if (!this.tokens) throw new Error("Sign in to continue");
    const user: CurrentUser = await this.request("/auth/me");
    if (user.role === "customer")
      throw new Error("A staff account is required");
    return user;
  }
  async request(
    path: string,
    init: RequestInit = {},
    retry = true,
  ): Promise<any> {
    const response = await fetch(baseUrl + path, {
      ...init,
      headers: {
        "Content-Type": "application/json",
        ...(this.tokens
          ? { Authorization: `Bearer ${this.tokens.access_token}` }
          : {}),
        ...init.headers,
      },
    });
    if (response.status === 401 && retry && this.tokens) {
      this.refreshing ??= this.refresh().finally(() => {
        this.refreshing = null;
      });
      if (await this.refreshing) return this.request(path, init, false);
    }
    if (!response.ok) {
      const error = await response.json().catch(() => ({}));
      throw new Error(
        typeof error.detail === "string"
          ? error.detail
          : "Please check the form and try again.",
      );
    }
    return response.json();
  }
  private save() {
    sessionStorage.setItem("scheme_tokens", JSON.stringify(this.tokens));
  }
  private async refresh() {
    try {
      this.tokens = await this.request(
        "/auth/refresh",
        {
          method: "POST",
          body: JSON.stringify({ refresh_token: this.tokens?.refresh_token }),
        },
        false,
      );
      this.save();
      return true;
    } catch {
      this.tokens = null;
      sessionStorage.removeItem("scheme_tokens");
      return false;
    }
  }
  async logout() {
    try {
      if (this.tokens)
        await this.request(
          "/auth/logout",
          {
            method: "POST",
            body: JSON.stringify({ refresh_token: this.tokens.refresh_token }),
          },
          false,
        );
    } finally {
      this.tokens = null;
      sessionStorage.removeItem("scheme_tokens");
    }
  }
}
