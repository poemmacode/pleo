import { Link, useParams } from 'react-router-dom'
import { usePageDetail } from '../api/hooks'
import { formatDetails, SEVERITY_BADGES } from './issueFormat'

export function PageDetailPage() {
  const crawlId = Number(useParams().crawlId)
  const pageId = Number(useParams().pageId)
  const detail = usePageDetail(crawlId, pageId)

  if (detail.isPending) return <main><p>Cargando…</p></main>
  if (detail.error) return <main><p role="alert" className="error">{detail.error.message}</p></main>

  const p = detail.data
  return (
    <main>
      <p><Link to={`/crawls/${crawlId}`}>← Crawl</Link></p>
      <h1 className="url">{p.url}</h1>
      <section className="card">
        <dl className="dns">
          <dt>Estado</dt><dd>{p.status_code ?? p.fetch_error}</dd>
          <dt>Indexable</dt><dd>{p.indexable ? 'sí' : `no (${p.indexability_reason})`}</dd>
          <dt>Title</dt><dd>{p.title ?? '—'}</dd>
          <dt>Description</dt><dd>{p.meta_description ?? '—'}</dd>
          <dt>Canonical</dt><dd>{p.canonical ?? (p.canonical_hrefs.length ? p.canonical_hrefs.join(', ') : '—')}</dd>
          <dt>Robots</dt><dd>{[p.meta_robots, p.x_robots_tag].filter(Boolean).join(' · ') || '—'}</dd>
          <dt>Idioma</dt><dd>{p.lang ?? '—'}</dd>
          <dt>Palabras</dt><dd>{p.word_count ?? '—'}</dd>
          <dt>Profundidad</dt><dd>{p.depth ?? '—'}</dd>
          <dt>Enlaces entrantes</dt><dd>{p.inlinks_count}</dd>
          <dt>Imágenes sin alt</dt><dd>{p.images_missing_alt ?? 0} de {p.images_count ?? 0}</dd>
        </dl>
      </section>

      <section className="card stack">
        <h2>Problemas</h2>
        {p.issues.length === 0 ? <p className="muted">Ninguno.</p> : (
          <ul className="plain">
            {p.issues.map((i) => (
              <li key={i.check_key}><span className={`badge sev-${i.severity}`}>{SEVERITY_BADGES[i.severity]}</span> {i.title}
                {Object.keys(i.details).length > 0 && <span className="muted"> — {formatDetails(i.details)}</span>}</li>
            ))}
          </ul>
        )}
      </section>

      <div className="grid">
        <section className="card">
          <h2>Encabezados</h2>
          <ul className="plain headings">
            {p.headings.map((h, i) => <li key={i} style={{ paddingLeft: (h.level - 1) * 12 }}><code>H{h.level}</code> {h.text}</li>)}
          </ul>
        </section>
        <section className="card">
          <h2>Datos estructurados</h2>
          {p.structured_data.length === 0 && <p className="muted">Sin marcado.</p>}
          <ul className="plain">
            {p.structured_data.map((s, i) => (
              <li key={i}>
                <code>{s.syntax}</code> {s.types.join(', ') || '(sin tipo)'} {!s.valid_syntax && <span className="error">sintaxis inválida</span>}
                {s.validation_errors.map((e, j) => <div key={j} className="error">{Object.values(e).join(' · ')}</div>)}
                {s.validation_warnings.slice(0, 5).map((w, j) => <div key={j} className="muted">{Object.values(w).join(' · ')}</div>)}
              </li>
            ))}
          </ul>
        </section>
      </div>

      <section className="card stack">
        <h2>Enlaces salientes ({p.outlinks.length})</h2>
        <div className="table-wrap">
          <table>
            <thead><tr><th>URL</th><th>Anchor</th><th>Tipo</th></tr></thead>
            <tbody>
              {p.outlinks.map((l, i) => (
                <tr key={i}><td className="url">{l.url}</td><td>{l.anchor}</td><td>{l.internal ? 'interno' : 'externo'}{l.rel.length ? ` (${l.rel.join(' ')})` : ''}</td></tr>
              ))}
            </tbody>
          </table>
        </div>
        <h2>Enlaces entrantes ({p.inlinks.length})</h2>
        <ul className="plain">{p.inlinks.map((l, i) => <li key={i}><code>{l.url}</code> {l.anchor && `— ${l.anchor}`}</li>)}</ul>
      </section>
    </main>
  )
}
