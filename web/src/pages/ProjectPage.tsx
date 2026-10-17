import { useState, type FormEvent } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { ApiError } from '../api/client'
import { useCreateDomain, useDeleteDomain, useDeleteProject, useProject, useVerifyDomain } from '../api/hooks'
import type { Domain, VerificationMethod } from '../api/types'

export function ProjectPage() {
  const projectId = Number(useParams().projectId)
  const project = useProject(projectId)
  const createDomain = useCreateDomain(projectId)
  const deleteProject = useDeleteProject()
  const navigate = useNavigate()
  const [host, setHost] = useState('')

  function submit(event: FormEvent) {
    event.preventDefault()
    createDomain.mutate(host, { onSuccess: () => setHost('') })
  }

  function remove() {
    if (!window.confirm('¿Eliminar este proyecto y sus dominios?')) return
    deleteProject.mutate(projectId, { onSuccess: () => navigate('/') })
  }

  if (project.isPending) return <main><p>Cargando…</p></main>
  if (project.error) return <main><p role="alert" className="error">{project.error.message}</p></main>

  const hostError = createDomain.error instanceof ApiError ? createDomain.error.fieldError('host') : undefined

  return (
    <main>
      <p><Link to="/">← Proyectos</Link></p>
      <h1>{project.data.name}</h1>

      <h2>Dominios</h2>
      <form onSubmit={submit} className="inline-form">
        <label>
          Añadir dominio
          <input value={host} onChange={(e) => setHost(e.target.value)} placeholder="ejemplo.com" aria-invalid={!!hostError} />
        </label>
        <button type="submit" disabled={createDomain.isPending}>Añadir</button>
      </form>
      {hostError && <p role="alert" className="error">{hostError}</p>}

      <ul className="list">
        {project.data.domains.map((domain) => (
          <DomainCard key={domain.id} domain={domain} projectId={projectId} />
        ))}
      </ul>

      <p><button className="danger" onClick={remove}>Eliminar proyecto</button></p>
    </main>
  )
}

const METHOD_LABELS: Record<VerificationMethod, string> = {
  dns_txt: 'Registro DNS TXT',
  html_file: 'Archivo en el servidor',
  meta: 'Etiqueta meta',
}

function DomainCard({ domain, projectId }: { domain: Domain; projectId: number }) {
  const verify = useVerifyDomain(projectId)
  const deleteDomain = useDeleteDomain(projectId)
  const [method, setMethod] = useState<VerificationMethod>('dns_txt')
  const { dns_txt: txt, html_file: file, meta } = domain.verification

  return (
    <li className="card stack">
      <div className="row">
        <strong>{domain.host}</strong>
        <span className={domain.verified ? 'badge ok' : 'badge'}>{domain.verified ? 'Verificado' : 'Sin verificar'}</span>
      </div>
      {!domain.verified && (
        <>
          <fieldset className="row methods">
            <legend>Método de verificación</legend>
            {(Object.keys(METHOD_LABELS) as VerificationMethod[]).map((key) => (
              <label key={key} className="radio">
                <input type="radio" name={`method-${domain.id}`} checked={method === key} onChange={() => setMethod(key)} />
                {METHOD_LABELS[key]}
              </label>
            ))}
          </fieldset>

          {method === 'dns_txt' && (
            <>
              <p>Crea este registro DNS en tu proveedor (la propagación puede tardar unos minutos):</p>
              <dl className="dns">
                <dt>Tipo</dt><dd>{txt.type}</dd>
                <dt>Nombre</dt><dd><code>{txt.name}</code></dd>
                <dt>Valor</dt><dd><code>{txt.value}</code></dd>
              </dl>
            </>
          )}
          {method === 'html_file' && (
            <>
              <p>Publica un archivo de texto en esta URL exacta (sin redirigir a otro host):</p>
              <dl className="dns">
                <dt>URL</dt><dd><code>{file.url}</code></dd>
                <dt>Contenido</dt><dd><code>{file.content}</code></dd>
              </dl>
            </>
          )}
          {method === 'meta' && (
            <>
              <p>Añade esta etiqueta dentro de <code>&lt;head&gt;</code> en la página de inicio de {domain.host}:</p>
              <p><code>{meta.tag}</code></p>
            </>
          )}

          {verify.error && <p role="alert" className="error">{verify.error.message}</p>}
          <div className="row">
            <button onClick={() => verify.mutate({ domainId: domain.id, method })} disabled={verify.isPending}>
              {verify.isPending ? 'Verificando…' : 'Verificar'}
            </button>
            <button className="secondary" onClick={() => deleteDomain.mutate(domain.id)}>Quitar</button>
          </div>
        </>
      )}
    </li>
  )
}
