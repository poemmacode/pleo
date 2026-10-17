import { describe, expect, it } from 'vitest'
import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { Route, Routes } from 'react-router-dom'
import { NewCrawlPage } from './NewCrawlPage'
import { CrawlPage } from './CrawlPage'
import { api, server } from '../test/server'
import { renderWithProviders } from '../test/render'
import type { Crawl, Domain, Project } from '../api/types'

const baseDomain = (overrides: Partial<Domain>): Domain => ({
  id: 1, project_id: 3, host: 'ejemplo.com', verified: true, verified_at: null, verification_method: 'dns_txt',
  verification: {
    available_methods: [], dns_txt: { name: '', type: 'TXT', value: '' }, html_file: { url: '', content: '' },
    meta: { tag: '' }, last_attempt_at: null, last_error: null,
  },
  ...overrides,
})

const project: Project = {
  id: 3, name: 'Blog', monthly_api_budget_cents: 0, created_at: '',
  domains: [baseDomain({}), baseDomain({ id: 2, host: 'rival.com', verified: false })],
}

const crawl: Crawl = {
  id: 9, project_id: 3, domain: { id: 1, host: 'ejemplo.com', verified: true }, status: 'running', status_reason: null,
  config: {} as Crawl['config'], current_rps: 2,
  progress: { discovered: 40, crawled: 10, failed: 0, skipped: 0, max_pages: 500 },
  sitemap_status: 'done', created_at: '', started_at: '', finished_at: null,
  skipped_by_reason: {}, status_codes: { '200': 9, '404': 1 }, sitemaps: [], hosts: [],
}

function renderNewCrawl(route = '/projects/3/crawls/new') {
  return renderWithProviders(
    <Routes>
      <Route path="/projects/:projectId/crawls/new" element={<NewCrawlPage />} />
      <Route path="/crawls/:crawlId" element={<p>página del crawl</p>} />
    </Routes>,
    { route },
  )
}

describe('NewCrawlPage', () => {
  it('submits the settings and opens the crawl', async () => {
    let body: Record<string, unknown> = {}
    server.use(
      http.get(api('/projects/3'), () => HttpResponse.json({ data: project })),
      http.post(api('/projects/3/crawls'), async ({ request }) => {
        body = ((await request.json()) as { crawl: Record<string, unknown> }).crawl
        return HttpResponse.json({ data: { ...crawl, status: 'queued' } }, { status: 202 })
      }),
    )
    const user = userEvent.setup()
    renderNewCrawl()

    await user.type(await screen.findByLabelText('Máximo de páginas'), '50')
    await user.type(screen.getByLabelText(/Excluir rutas/), '^/tag/{enter}^/wp-admin')
    await user.click(screen.getByRole('button', { name: 'Iniciar crawl' }))

    expect(await screen.findByText('página del crawl')).toBeInTheDocument()
    expect(body).toMatchObject({
      domain_id: 1, max_pages: 50, requests_per_second: 2, exclude_patterns: ['^/tag/', '^/wp-admin'], use_sitemaps: true,
    })
  })

  it('warns about limits and asks for the terms on unverified domains, showing field errors', async () => {
    server.use(
      http.get(api('/projects/3'), () => HttpResponse.json({ data: project })),
      http.post(api('/projects/3/crawls'), () =>
        HttpResponse.json({ errors: [{ code: 'invalid', detail: 'Máximo de páginas debe estar entre 1 y 200 (dominio sin verificar)', field: 'max_pages' }] }, { status: 422 }),
      ),
    )
    const user = userEvent.setup()
    renderNewCrawl('/projects/3/crawls/new?domain=2')

    expect(await screen.findByText(/Dominio sin verificar/)).toBeInTheDocument()
    expect(screen.getByLabelText(/términos de rival.com/)).toBeInTheDocument()
    expect(screen.getByLabelText('Máximo de páginas')).toHaveAttribute('placeholder', '200')
    expect(screen.getByLabelText('Peticiones por segundo')).toHaveAttribute('placeholder', '0.5')
    await user.click(screen.getByRole('button', { name: 'Iniciar crawl' }))

    expect(await screen.findByText(/entre 1 y 200/)).toBeInTheDocument()
  })
})

describe('CrawlPage', () => {
  it('shows progress and pauses the crawl', async () => {
    server.use(
      http.get(api('/crawls/9'), () => HttpResponse.json({ data: crawl })),
      http.get(api('/crawls/9/pages'), () =>
        HttpResponse.json({
          data: [{ id: 1, url: 'https://ejemplo.com/vieja', depth: 1, in_sitemap: false, status_code: 301, redirect_url: 'https://ejemplo.com/nueva', fetch_error: null, content_type: null, content_length: 0, truncated: false, response_ms: 40 }],
          meta: { next_cursor: null },
        }),
      ),
      http.post(api('/crawls/9/pause'), () => HttpResponse.json({ data: { ...crawl, status: 'paused', status_reason: 'user' } })),
    )
    const user = userEvent.setup()
    renderWithProviders(<Routes><Route path="/crawls/:crawlId" element={<CrawlPage />} /></Routes>, { route: '/crawls/9' })

    expect(await screen.findByText('Rastreando')).toBeInTheDocument()
    expect(await screen.findByText('→ https://ejemplo.com/nueva')).toBeInTheDocument()
    expect(screen.getByRole('progressbar')).toHaveAttribute('aria-valuenow', '25')

    await user.click(screen.getByRole('button', { name: 'Pausar' }))
    await waitFor(() => expect(screen.getByText('En pausa')).toBeInTheDocument())
    expect(screen.getByRole('button', { name: 'Reanudar' })).toBeInTheDocument()
  })
})
