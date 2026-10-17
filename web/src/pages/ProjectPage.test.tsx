import { describe, expect, it } from 'vitest'
import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { Route, Routes } from 'react-router-dom'
import { ProjectPage } from './ProjectPage'
import { api, server } from '../test/server'
import { renderWithProviders } from '../test/render'
import type { Domain, Project } from '../api/types'

const domain: Domain = {
  id: 7,
  project_id: 3,
  host: 'ejemplo.com',
  verified: false,
  verified_at: null,
  verification_method: null,
  verification: {
    available_methods: ['dns_txt'],
    dns_txt: { name: 'ejemplo.com', type: 'TXT', value: 'seo-platform-verify=abc' },
    last_attempt_at: null,
    last_error: null,
  },
}

const project: Project = { id: 3, name: 'Blog', monthly_api_budget_cents: 0, domains: [domain], created_at: '' }

function renderPage() {
  return renderWithProviders(
    <Routes>
      <Route path="/projects/:projectId" element={<ProjectPage />} />
    </Routes>,
    { route: '/projects/3' },
  )
}

describe('ProjectPage', () => {
  it('shows DNS instructions and the verification failure reason', async () => {
    server.use(
      http.get(api('/projects/3'), () => HttpResponse.json({ data: project })),
      http.post(api('/domains/7/verify'), () =>
        HttpResponse.json(
          { errors: [{ code: 'verification_failed', detail: 'No se encontró el registro TXT', field: 'method' }] },
          { status: 422 },
        ),
      ),
    )
    const user = userEvent.setup()
    renderPage()

    expect(await screen.findByText('seo-platform-verify=abc')).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Verificar' }))

    expect(await screen.findByRole('alert')).toHaveTextContent('No se encontró el registro TXT')
  })

  it('shows the server reason when a domain is rejected', async () => {
    server.use(
      http.get(api('/projects/3'), () => HttpResponse.json({ data: { ...project, domains: [] } })),
      http.post(api('/projects/3/domains'), () =>
        HttpResponse.json(
          { errors: [{ code: 'invalid', detail: 'Host no puede ser una dirección IP', field: 'host' }] },
          { status: 422 },
        ),
      ),
    )
    const user = userEvent.setup()
    renderPage()

    await user.type(await screen.findByLabelText('Añadir dominio'), '127.0.0.1')
    await user.click(screen.getByRole('button', { name: 'Añadir' }))

    expect(await screen.findByRole('alert')).toHaveTextContent('Host no puede ser una dirección IP')
    expect(screen.getByLabelText('Añadir dominio')).toHaveAttribute('aria-invalid', 'true')
  })
})
