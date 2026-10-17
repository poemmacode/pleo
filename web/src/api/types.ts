export type User = { id: number; email: string }

export type Domain = {
  id: number
  project_id: number
  host: string
  verified: boolean
  verified_at: string | null
  verification_method: string | null
  verification: {
    available_methods: string[]
    dns_txt: { name: string; type: 'TXT'; value: string }
    html_file: { url: string; content: string }
    meta: { tag: string }
    last_attempt_at: string | null
    last_error: string | null
  }
}

export type VerificationMethod = 'dns_txt' | 'html_file' | 'meta'

export type Project = {
  id: number
  name: string
  monthly_api_budget_cents: number
  domains: Domain[]
  created_at: string
}

export type Envelope<T> = { data: T; meta?: Record<string, unknown> }
