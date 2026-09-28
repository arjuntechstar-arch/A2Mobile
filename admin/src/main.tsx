/// <reference types="vite/client" />
import { FormEvent, useEffect, useState } from 'react'
import { createRoot } from 'react-dom/client'
import { ApiClient, CurrentUser } from './api'
import './styles.css'

const api = new ApiClient()
function App() {
  const [user, setUser] = useState<CurrentUser | null>(null)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)
  useEffect(() => { api.me().then(setUser).catch(() => undefined).finally(() => setLoading(false)) }, [])
  async function signIn(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setError('')
    const form = new FormData(event.currentTarget)
    try { setUser(await api.login(String(form.get('email')), String(form.get('password')))) } catch (err) { setError(err instanceof Error ? err.message : 'Unable to sign in') }
  }
  if (loading) return <main>Loading secure admin portal…</main>
  if (!user) return <main className="card"><h1>Scheme Admin</h1><p>Sign in with an authorized staff account.</p><form onSubmit={signIn}><label>Email<input name="email" type="email" required autoComplete="email" /></label><label>Password<input name="password" type="password" required minLength={8} autoComplete="current-password" /></label>{error && <p role="alert">{error}</p>}<button>Sign in</button></form></main>
  return <main className="card"><h1>Welcome, {user.email}</h1><p>Role: {user.role}</p><p>Phase 1 access control is active. Operational modules arrive in their scheduled phases.</p><button onClick={() => { api.logout(); setUser(null) }}>Sign out</button></main>
}
createRoot(document.getElementById('root')!).render(<App />)
