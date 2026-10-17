import { useState } from 'react'
import { Link } from 'react-router-dom'
import { useCrawlIssues, useIssueFindings } from '../api/hooks'
import type { Crawl, IssueSummary, Severity } from '../api/types'
import { formatDetails, SEVERITY_BADGES, SEVERITY_LABELS } from './issueFormat'

export function IssuesSection({ crawl }: { crawl: Crawl }) {
  const issues = useCrawlIssues(crawl.id, crawl.audited_at)

  if (crawl.status !== 'completed') return null
  if (crawl.audit_status === 'failed') {
    return <section className="card"><h2>Auditoría</h2><p role="alert" className="error">La auditoría falló: {crawl.audit_error}</p></section>
  }
  if (crawl.audit_status !== 'done') return <section className="card"><h2>Auditoría</h2><p className="muted">Analizando las páginas…</p></section>
  if (!issues.data) return null

  const bySeverity = issues.data.meta.by_severity
  return (
    <section className="card stack">
      <h2>Auditoría</h2>
      <dl className="stats">
        {(Object.keys(SEVERITY_LABELS) as Severity[]).map((s) => (
          <div key={s}><dt>{SEVERITY_LABELS[s]}</dt><dd className={`sev-${s}`}>{bySeverity[s] ?? 0}</dd></div>
        ))}
      </dl>
      {issues.data.data.length === 0 && <p>No se encontraron problemas.</p>}
      <ul className="plain issues">
        {issues.data.data.map((issue) => <IssueRow key={issue.check_key} crawlId={crawl.id} issue={issue} />)}
      </ul>
    </section>
  )
}

function IssueRow({ crawlId, issue }: { crawlId: number; issue: IssueSummary }) {
  const [open, setOpen] = useState(false)
  return (
    <li>
      <button className="issue-toggle" aria-expanded={open} onClick={() => setOpen(!open)}>
        <span className={`badge sev-${issue.severity}`}>{SEVERITY_BADGES[issue.severity]}</span>
        <span className="issue-title">{issue.title}</span>
        <span className="muted">{issue.count}</span>
      </button>
      {open && <IssueFindings crawlId={crawlId} issue={issue} />}
    </li>
  )
}

function IssueFindings({ crawlId, issue }: { crawlId: number; issue: IssueSummary }) {
  const findings = useIssueFindings(crawlId, issue.check_key)
  const rows = findings.data?.pages.flatMap((p) => p.data) ?? []
  return (
    <div className="issue-body stack">
      <p>{issue.description}</p>
      <p><strong>Cómo arreglarlo:</strong> {issue.how_to_fix}</p>
      <ul className="plain">
        {rows.map((f) => (
          <li key={f.id}>
            {f.page_id ? <Link to={`/crawls/${crawlId}/pages/${f.page_id}`}>{f.url}</Link> : <code>{f.url ?? 'Todo el sitio'}</code>}
            {Object.keys(f.details).length > 0 && <div className="muted">{formatDetails(f.details)}</div>}
          </li>
        ))}
      </ul>
      {findings.hasNextPage && (
        <div><button className="secondary" onClick={() => findings.fetchNextPage()}>Cargar más</button></div>
      )}
    </div>
  )
}
