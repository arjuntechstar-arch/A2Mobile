export type CurrentUser = { id: string; email: string; role: string; permissions: string[] }
type Tokens = { access_token: string; refresh_token: string }
const baseUrl = import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:8000/api'

export class ApiClient {
  private tokens: Tokens | null = JSON.parse(sessionStorage.getItem('scheme_tokens') ?? 'null')

  async login(email: string, password: string): Promise<CurrentUser> {
    const response = await fetch(`${baseUrl}/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password }) })
    if (!response.ok) throw new Error('Invalid email or password')
    this.tokens = await response.json()
    sessionStorage.setItem('scheme_tokens', JSON.stringify(this.tokens))
    return this.me()
  }

  async me(): Promise<CurrentUser> {
    if (!this.tokens) throw new Error('Not signed in')
    let response = await this.authorized('/auth/me')
    if (response.status === 401 && await this.refresh()) response = await this.authorized('/auth/me')
    if (!response.ok) { this.logout(); throw new Error('Session expired') }
    return response.json()
  }

  logout() { this.tokens = null; sessionStorage.removeItem('scheme_tokens') }
  private authorized(path: string) { return fetch(`${baseUrl}${path}`, { headers: { Authorization: `Bearer ${this.tokens?.access_token}` } }) }
  private async refresh(): Promise<boolean> {
    if (!this.tokens) return false
    const response = await fetch(`${baseUrl}/auth/refresh`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ refresh_token: this.tokens.refresh_token }) })
    if (!response.ok) return false
    this.tokens = await response.json(); sessionStorage.setItem('scheme_tokens', JSON.stringify(this.tokens)); return true
  }
}
