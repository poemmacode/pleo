export type ApiErrorItem = { code: string; detail: string; field?: string }

export class ApiError extends Error {
  readonly status: number
  readonly errors: ApiErrorItem[]

  constructor(status: number, errors: ApiErrorItem[]) {
    super(errors[0]?.detail ?? `Error ${status}`)
    this.status = status
    this.errors = errors
  }

  fieldError(field: string): string | undefined {
    return this.errors.find((error) => error.field === field)?.detail
  }
}

let csrfToken: string | null = null

// Absolute URL so the same code runs in the browser and under the Node fetch used by tests.
const apiUrl = (path: string) => new URL(`/api/v1${path}`, window.location.origin)

export function setCsrfToken(token: string | null) {
  csrfToken = token
}

async function fetchCsrfToken(): Promise<string> {
  const response = await fetch(apiUrl('/csrf_token'), { credentials: 'same-origin' })
  const body = await response.json()
  csrfToken = body.data.token as string
  return csrfToken
}

export async function apiRequest<T>(method: string, path: string, body?: unknown): Promise<T> {
  const headers: Record<string, string> = { Accept: 'application/json' }
  if (body !== undefined) headers['Content-Type'] = 'application/json'
  if (method !== 'GET') headers['X-CSRF-Token'] = csrfToken ?? (await fetchCsrfToken())

  const response = await fetch(apiUrl(path), {
    method,
    headers,
    credentials: 'same-origin',
    body: body === undefined ? undefined : JSON.stringify(body),
  })

  if (response.status === 204) return undefined as T

  const payload = await response.json().catch(() => ({}))
  if (!response.ok) {
    // A stale CSRF token (e.g. after logout rotated the session) is refreshed on the next call.
    if (response.status === 403) csrfToken = null
    throw new ApiError(response.status, payload.errors ?? [])
  }
  return payload as T
}
