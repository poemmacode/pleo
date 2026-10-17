import { useState, type FormEvent, type ReactNode } from 'react'
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom'
import { ApiError } from '../api/client'
import { useCreateCrawl, useProject, type NewCrawl } from '../api/hooks'

const lines = (text: string) => text.split('\n').map((line) => line.trim()).filter(Boolean)

// Defaults within each domain's limits; empty inputs fall back to these.
const DEFAULTS = {
  verified: { max_pages: 500, requests_per_second: 2 },
  unverified: { max_pages: 200, requests_per_second: 0.5 },
}

export function NewCrawlPage() {
  const projectId = Number(useParams().projectId)
  const [searchParams] = useSearchParams()
  const project = useProject(projectId)
  const createCrawl = useCreateCrawl(projectId)
  const navigate = useNavigate()
  const [domainId, setDomainId] = useState(Number(searchParams.get('domain')) || 0)
  const [form, setForm] = useState({
    start_url: '',
    scope: 'domain',
    max_pages: '',
    max_depth: '10',
    requests_per_second: '',
    device: 'desktop',
    use_sitemaps: true,
    respect_nofollow: false,
    include_patterns: '',
    exclude_patterns: '',
    terms_accepted: false,
  })

  if (project.isPending) return <main><p>Cargando…</p></main>
  if (project.error) return <main><p role="alert" className="error">{project.error.message}</p></main>

  const domains = project.data.domains
  const domain = domains.find((d) => d.id === domainId) ?? domains[0]
  const unverified = domain && !domain.verified
  const defaults = DEFAULTS[unverified ? 'unverified' : 'verified']
  const fieldError = (field: string) =>
    createCrawl.error instanceof ApiError ? createCrawl.error.fieldError(field) : undefined
  const generalError =
    createCrawl.error instanceof ApiError && createCrawl.error.errors.every((e) => !e.field) ? createCrawl.error.message : undefined
  const set = (key: keyof typeof form) => (value: string | boolean) => setForm((f) => ({ ...f, [key]: value }))

  function submit(event: FormEvent) {
    event.preventDefault()
    if (!domain) return
    const payload: NewCrawl = {
      domain_id: domain.id,
      start_url: form.start_url || undefined,
      scope: form.scope as NewCrawl['scope'],
      max_pages: Number(form.max_pages) || defaults.max_pages,
      max_depth: Number(form.max_depth),
      requests_per_second: Number(form.requests_per_second) || defaults.requests_per_second,
      device: form.device as NewCrawl['device'],
      use_sitemaps: form.use_sitemaps,
      respect_nofollow: form.respect_nofollow,
      include_patterns: lines(form.include_patterns),
      exclude_patterns: lines(form.exclude_patterns),
      terms_accepted: form.terms_accepted,
    }
    createCrawl.mutate(payload, { onSuccess: (response) => navigate(`/crawls/${response.data.id}`) })
  }

  if (!domain) {
    return (
      <main>
        <p><Link to={`/projects/${projectId}`}>← {project.data.name}</Link></p>
        <p>Añade primero un dominio al proyecto.</p>
      </main>
    )
  }

  return (
    <main>
      <p><Link to={`/projects/${projectId}`}>← {project.data.name}</Link></p>
      <h1>Nuevo crawl</h1>
      <form onSubmit={submit} className="card stack">
        <Field label="Dominio" error={fieldError('domain_id')}>
          <select value={domain.id} onChange={(e) => setDomainId(Number(e.target.value))}>
            {domains.map((d) => (
              <option key={d.id} value={d.id}>{d.host}{d.verified ? '' : ' (sin verificar)'}</option>
            ))}
          </select>
        </Field>
        {unverified && (
          <p className="notice">
            Dominio sin verificar: máximo 200 páginas a 0,5 peticiones/s. Verifícalo para auditar sitios completos.
          </p>
        )}
        <Field label="URL inicial" hint={`Vacío = https://${domain.host}/`} error={fieldError('start_url')}>
          <input value={form.start_url} onChange={(e) => set('start_url')(e.target.value)} placeholder={`https://${domain.host}/`} />
        </Field>
        <div className="grid">
          <Field label="Alcance" error={fieldError('scope')}>
            <select value={form.scope} onChange={(e) => set('scope')(e.target.value)}>
              <option value="domain">Dominio y subdominios</option>
              <option value="subdomain">Solo este host</option>
              <option value="subfolder">Solo esta carpeta</option>
            </select>
          </Field>
          <Field label="Dispositivo" error={fieldError('device')}>
            <select value={form.device} onChange={(e) => set('device')(e.target.value)}>
              <option value="desktop">Escritorio</option>
              <option value="mobile">Móvil</option>
            </select>
          </Field>
          <Field label="Máximo de páginas" error={fieldError('max_pages')}>
            <input type="number" min={1} placeholder={String(defaults.max_pages)} value={form.max_pages} onChange={(e) => set('max_pages')(e.target.value)} />
          </Field>
          <Field label="Peticiones por segundo" error={fieldError('requests_per_second')}>
            <input type="number" step="0.1" min={0.2} placeholder={String(defaults.requests_per_second)} value={form.requests_per_second} onChange={(e) => set('requests_per_second')(e.target.value)} />
          </Field>
          <Field label="Profundidad máxima" error={fieldError('max_depth')}>
            <input type="number" min={0} value={form.max_depth} onChange={(e) => set('max_depth')(e.target.value)} />
          </Field>
        </div>
        <Field label="Excluir rutas (regex, una por línea)" hint="Se aplican a ruta + query, p. ej. ^/wp-admin" error={fieldError('exclude_patterns')}>
          <textarea rows={3} value={form.exclude_patterns} onChange={(e) => set('exclude_patterns')(e.target.value)} />
        </Field>
        <Field label="Incluir solo rutas (regex, una por línea)" error={fieldError('include_patterns')}>
          <textarea rows={2} value={form.include_patterns} onChange={(e) => set('include_patterns')(e.target.value)} />
        </Field>
        <label className="check">
          <input type="checkbox" checked={form.use_sitemaps} onChange={(e) => set('use_sitemaps')(e.target.checked)} />
          Descubrir URLs desde los sitemaps
        </label>
        <label className="check">
          <input type="checkbox" checked={form.respect_nofollow} onChange={(e) => set('respect_nofollow')(e.target.checked)} />
          No seguir enlaces nofollow
        </label>
        {unverified && (
          <label className="check">
            <input type="checkbox" checked={form.terms_accepted} onChange={(e) => set('terms_accepted')(e.target.checked)} />
            He revisado que los términos de {domain.host} permiten este rastreo
          </label>
        )}
        {fieldError('terms_accepted') && <p role="alert" className="error">{fieldError('terms_accepted')}</p>}
        {generalError && <p role="alert" className="error">{generalError}</p>}
        <p className="muted">Se respeta siempre robots.txt y su Crawl-delay. El bot se identifica como SEOPlatformBot.</p>
        <div><button type="submit" disabled={createCrawl.isPending}>{createCrawl.isPending ? 'Iniciando…' : 'Iniciar crawl'}</button></div>
      </form>
    </main>
  )
}

function Field({ label, hint, error, children }: { label: string; hint?: string; error?: string; children: ReactNode }) {
  return (
    <label>
      {label}
      {children}
      {hint && <span className="muted">{hint}</span>}
      {error && <span role="alert" className="error">{error}</span>}
    </label>
  )
}
