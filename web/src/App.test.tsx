import { describe, expect, it } from 'vitest'
import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { AppRoutes } from './App'
import { api, server } from './test/server'
import { renderWithProviders } from './test/render'

describe('authentication flow', () => {
  it('shows the login form, then the projects after signing in', async () => {
    let signedIn = false
    server.use(
      http.get(api('/session'), () =>
        signedIn
          ? HttpResponse.json({ data: { id: 1, email: 'ana@example.com' } })
          : HttpResponse.json({ errors: [{ code: 'unauthenticated', detail: 'Inicia sesión' }] }, { status: 401 }),
      ),
      http.post(api('/session'), async ({ request }) => {
        const body = (await request.json()) as { password: string }
        if (body.password !== 'correct horse battery') {
          return HttpResponse.json({ errors: [{ code: 'invalid_credentials', detail: 'Correo o contraseña incorrectos' }] }, { status: 401 })
        }
        signedIn = true
        return HttpResponse.json({ data: { id: 1, email: 'ana@example.com' }, meta: { csrf_token: 'rotated' } }, { status: 201 })
      }),
      http.get(api('/projects'), () => HttpResponse.json({ data: [] })),
    )
    const user = userEvent.setup()
    renderWithProviders(<AppRoutes />)

    await user.type(await screen.findByLabelText('Correo'), 'ana@example.com')
    await user.type(screen.getByLabelText('Contraseña'), 'wrong password')
    await user.click(screen.getByRole('button', { name: 'Entrar' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('Correo o contraseña incorrectos')

    await user.clear(screen.getByLabelText('Contraseña'))
    await user.type(screen.getByLabelText('Contraseña'), 'correct horse battery')
    await user.click(screen.getByRole('button', { name: 'Entrar' }))

    expect(await screen.findByRole('heading', { name: 'Proyectos' })).toBeInTheDocument()
    expect(screen.getByText('Aún no tienes proyectos.')).toBeInTheDocument()
  })
})
