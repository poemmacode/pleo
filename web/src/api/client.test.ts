import { describe, expect, it } from 'vitest'
import { http, HttpResponse } from 'msw'
import { ApiError, apiRequest } from './client'
import { api, server } from '../test/server'

describe('apiRequest', () => {
  it('sends the CSRF token on state-changing requests', async () => {
    let received: string | null = null
    server.use(
      http.post(api('/projects'), ({ request }) => {
        received = request.headers.get('X-CSRF-Token')
        return HttpResponse.json({ data: { id: 1 } }, { status: 201 })
      }),
    )

    await apiRequest('POST', '/projects', { project: { name: 'x' } })

    expect(received).toBe('csrf-123')
  })

  it('raises ApiError with field errors', async () => {
    server.use(
      http.post(api('/projects'), () =>
        HttpResponse.json({ errors: [{ code: 'invalid', detail: 'Nombre no puede estar vacío', field: 'name' }] }, { status: 422 }),
      ),
    )

    const error = await apiRequest<never>('POST', '/projects', {}).catch((e: ApiError) => e)

    expect(error).toBeInstanceOf(ApiError)
    expect(error.status).toBe(422)
    expect(error.fieldError('name')).toBe('Nombre no puede estar vacío')
  })
})
