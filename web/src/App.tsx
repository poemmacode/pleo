import { BrowserRouter, Route, Routes } from 'react-router-dom'
import { useLogout, useSession } from './api/hooks'
import { CrawlPage } from './pages/CrawlPage'
import { LoginPage } from './pages/LoginPage'
import { NewCrawlPage } from './pages/NewCrawlPage'
import { ProjectPage } from './pages/ProjectPage'
import { ProjectsPage } from './pages/ProjectsPage'

export function AppRoutes() {
  const session = useSession()
  const logout = useLogout()

  if (session.isPending) return <main><p>Cargando…</p></main>
  if (session.error) return <main><p role="alert" className="error">No se pudo contactar con la API.</p></main>
  if (!session.data) return <LoginPage />

  return (
    <>
      <header className="topbar">
        <span>SEO Platform</span>
        <span className="row">
          <span className="muted">{session.data.email}</span>
          <button className="secondary" onClick={() => logout.mutate()}>Salir</button>
        </span>
      </header>
      <Routes>
        <Route path="/" element={<ProjectsPage />} />
        <Route path="/projects/:projectId" element={<ProjectPage />} />
        <Route path="/projects/:projectId/crawls/new" element={<NewCrawlPage />} />
        <Route path="/crawls/:crawlId" element={<CrawlPage />} />
      </Routes>
    </>
  )
}

export default function App() {
  return (
    <BrowserRouter>
      <AppRoutes />
    </BrowserRouter>
  )
}
