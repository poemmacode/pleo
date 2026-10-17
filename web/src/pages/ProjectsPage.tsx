import { useState, type FormEvent } from 'react'
import { Link } from 'react-router-dom'
import { ApiError } from '../api/client'
import { useCreateProject, useProjects } from '../api/hooks'

export function ProjectsPage() {
  const projects = useProjects()
  const createProject = useCreateProject()
  const [name, setName] = useState('')

  function submit(event: FormEvent) {
    event.preventDefault()
    createProject.mutate(name, { onSuccess: () => setName('') })
  }

  const nameError = createProject.error instanceof ApiError ? createProject.error.fieldError('name') : undefined

  return (
    <main>
      <h1>Proyectos</h1>
      <form onSubmit={submit} className="inline-form">
        <label>
          Nuevo proyecto
          <input value={name} onChange={(e) => setName(e.target.value)} placeholder="Mi blog" aria-invalid={!!nameError} />
        </label>
        <button type="submit" disabled={createProject.isPending}>Crear</button>
      </form>
      {nameError && <p role="alert" className="error">{nameError}</p>}

      {projects.isPending && <p>Cargando…</p>}
      {projects.error && <p role="alert" className="error">{projects.error.message}</p>}
      {projects.data?.length === 0 && <p className="muted">Aún no tienes proyectos.</p>}
      <ul className="list">
        {projects.data?.map((project) => (
          <li key={project.id} className="card">
            <Link to={`/projects/${project.id}`}>{project.name}</Link>
            <span className="muted">
              {project.domains.length} dominio(s) · {project.domains.filter((d) => d.verified).length} verificado(s)
            </span>
          </li>
        ))}
      </ul>
    </main>
  )
}
