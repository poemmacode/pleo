import { setupServer } from 'msw/node'
import { http, HttpResponse } from 'msw'

export const api = (path: string) => `http://localhost:3000/api/v1${path}`

export const server = setupServer(
  http.get(api('/csrf_token'), () => HttpResponse.json({ data: { token: 'csrf-123' } })),
)
