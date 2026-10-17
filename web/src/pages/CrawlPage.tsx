import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { FINISHED_STATUSES, useCrawl, useCrawlAction, useCrawlPages } from '../api/hooks'
import type { Crawl } from '../api/types'

const STATUS_LABELS: Record<Crawl['status'], string> = {
  queued: 'En cola',
  running: 'Rastreando',
  paused: 'En pausa',
  completed: 'Completado',
  failed: 'Fallido',
  cancelled: 'Cancelado',
}

const REASON_LABELS: Record<string, string> = {
  user: 'por el usuario',
  server_overloaded: 'el servidor respondía con errores; se redujo la velocidad y se pausó',
  max_pages_reached: 'se alcanzó el máximo de páginas',
  robots_unreachable: 'robots.txt no responde: no se rastrea nada (RFC 9309)',
}

const ROBOTS_LABELS: Record<string, string> = {
  parsed: 'robots.txt leído',
  unavailable: 'sin robots.txt (todo permitido)',
  unreachable: 'robots.txt inaccesible (nada permitido)',
}

const SKIP_LABELS: Record<string, string> = {
  robots: 'Bloqueadas por robots.txt',
  limit: 'Fuera del límite de páginas',
  unsafe_host: 'Host no permitido (IP privada)',
  error: 'Error repetido',
  cancelled: 'Crawl cancelado',
}

export function CrawlPage() {
  const id = Number(useParams().crawlId)
  const crawl = useCrawl(id)
  const action = useCrawlAction(id)

  if (crawl.isPending) return <main><p>Cargando…</p></main>
  if (crawl.error) return <main><p role="alert" className="error">{crawl.error.message}</p></main>

  const c = crawl.data
  const done = c.progress.crawled + c.progress.failed
  const target = Math.min(c.progress.max_pages, Math.max(c.progress.discovered - c.progress.skipped, done, 1))
  const percent = FINISHED_STATUSES.includes(c.status) ? 100 : Math.min(99, Math.round((done / target) * 100))

  return (
    <main>
      <p><Link to={`/projects/${c.project_id}`}>← Proyecto</Link></p>
      <h1>Crawl de {c.domain.host}</h1>
      <section className="card stack">
        <div className="row">
          <span className={`badge status-${c.status}`}>{STATUS_LABELS[c.status]}</span>
          {c.status_reason && <span className="muted">{REASON_LABELS[c.status_reason] ?? c.status_reason}</span>}
          <span className="muted">{c.current_rps} pet./s</span>
        </div>
        <div className="progress" role="progressbar" aria-valuenow={percent} aria-valuemin={0} aria-valuemax={100}>
          <div style={{ width: `${percent}%` }} />
        </div>
        <dl className="stats">
          <div><dt>Descubiertas</dt><dd>{c.progress.discovered}</dd></div>
          <div><dt>Rastreadas</dt><dd>{c.progress.crawled}</dd></div>
          <div><dt>Con error</dt><dd>{c.progress.failed}</dd></div>
          <div><dt>Omitidas</dt><dd>{c.progress.skipped}</dd></div>
          <div><dt>Límite</dt><dd>{c.progress.max_pages}</dd></div>
        </dl>
        {action.error && <p role="alert" className="error">{action.error.message}</p>}
        <div className="row">
          {c.status === 'running' && <button className="secondary" onClick={() => action.mutate('pause')}>Pausar</button>}
          {c.status === 'paused' && <button onClick={() => action.mutate('resume')}>Reanudar</button>}
          {!FINISHED_STATUSES.includes(c.status) && (
            <button className="danger" onClick={() => window.confirm('¿Cancelar el crawl?') && action.mutate('cancel')}>Cancelar</button>
          )}
        </div>
      </section>

      <CrawlDetails crawl={c} />
      <PagesTable crawlId={id} refreshKey={done} />
    </main>
  )
}

function CrawlDetails({ crawl }: { crawl: Crawl }) {
  const skipped = Object.entries(crawl.skipped_by_reason ?? {})
  const codes = Object.entries(crawl.status_codes ?? {})
  return (
    <div className="grid">
      <section className="card">
        <h2>Códigos de estado</h2>
        {codes.length === 0 ? <p className="muted">Aún no hay páginas.</p> : (
          <ul className="plain">{codes.map(([code, n]) => <li key={code}><code>{code === 'error' ? 'sin respuesta' : code}</code> {n}</li>)}</ul>
        )}
        {skipped.length > 0 && (
          <>
            <h2>Omitidas</h2>
            <ul className="plain">{skipped.map(([reason, n]) => <li key={reason}>{SKIP_LABELS[reason] ?? reason}: {n}</li>)}</ul>
          </>
        )}
      </section>
      <section className="card">
        <h2>robots.txt y sitemaps</h2>
        <ul className="plain">
          {crawl.hosts?.map((h) => (
            <li key={h.host}>{h.host}: {ROBOTS_LABELS[h.robots_outcome] ?? h.robots_outcome}{h.robots_status ? ` (${h.robots_status})` : ''}{h.crawl_delay ? `, Crawl-delay ${h.crawl_delay}s` : ''}</li>
          ))}
        </ul>
        {crawl.sitemap_status === 'pending' && <p className="muted">Leyendo sitemaps…</p>}
        <ul className="plain">
          {crawl.sitemaps?.map((s) => (
            <li key={s.url}><code>{s.url}</code> — {s.error ?? `${s.status}: ${s.urls} URLs, ${s.added} nuevas`}</li>
          ))}
        </ul>
      </section>
    </div>
  )
}

function PagesTable({ crawlId, refreshKey }: { crawlId: number; refreshKey: number }) {
  const [status, setStatus] = useState('')
  // Refresh the first page as the crawl progresses, but not on every poll.
  const pages = useCrawlPages(crawlId, status, Math.floor(refreshKey / 25))
  const rows = pages.data?.pages.flatMap((p) => p.data) ?? []

  return (
    <section className="card stack">
      <div className="row">
        <h2>Páginas</h2>
        <label className="inline">
          Estado
          <select value={status} onChange={(e) => setStatus(e.target.value)}>
            <option value="">Todos</option>
            <option value="2xx">2xx</option>
            <option value="3xx">3xx</option>
            <option value="4xx">4xx</option>
            <option value="5xx">5xx</option>
            <option value="error">Sin respuesta</option>
          </select>
        </label>
      </div>
      <div className="table-wrap">
        <table>
          <thead>
            <tr><th>URL</th><th>Estado</th><th>Prof.</th><th>Sitemap</th><th>ms</th></tr>
          </thead>
          <tbody>
            {rows.map((page) => (
              <tr key={page.id}>
                <td className="url">
                  {page.url}
                  {page.redirect_url && <div className="muted">→ {page.redirect_url}</div>}
                  {page.fetch_error && <div className="error">{page.fetch_error}</div>}
                </td>
                <td>{page.status_code ?? '—'}</td>
                <td>{page.depth ?? '—'}</td>
                <td>{page.in_sitemap ? 'sí' : ''}</td>
                <td>{page.response_ms ?? ''}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {rows.length === 0 && !pages.isPending && <p className="muted">Sin páginas para este filtro.</p>}
      {pages.hasNextPage && (
        <div><button className="secondary" onClick={() => pages.fetchNextPage()} disabled={pages.isFetchingNextPage}>Cargar más</button></div>
      )}
    </section>
  )
}
