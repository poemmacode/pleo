import { useInfiniteQuery, useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ApiError, apiRequest, setCsrfToken } from './client'
import type { Crawl, CrawlConfig, CrawlPage, Domain, Envelope, Finding, IssueSummary, PageDetail, Project, User, VerificationMethod } from './types'

export function useSession() {
  return useQuery({
    queryKey: ['session'],
    queryFn: async () => {
      try {
        return (await apiRequest<Envelope<User>>('GET', '/session')).data
      } catch (error) {
        if (error instanceof ApiError && error.status === 401) return null
        throw error
      }
    },
  })
}

export function useLogin() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (credentials: { email: string; password: string }) =>
      apiRequest<Envelope<User>>('POST', '/session', credentials),
    onSuccess: (response) => {
      setCsrfToken((response.meta?.csrf_token as string | undefined) ?? null)
      queryClient.setQueryData(['session'], response.data)
    },
  })
}

export function useLogout() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: () => apiRequest<void>('DELETE', '/session'),
    onSuccess: () => {
      setCsrfToken(null)
      queryClient.clear()
      queryClient.setQueryData(['session'], null)
    },
  })
}

export function useProjects() {
  return useQuery({
    queryKey: ['projects'],
    queryFn: async () => (await apiRequest<Envelope<Project[]>>('GET', '/projects')).data,
  })
}

export function useProject(id: number) {
  return useQuery({
    queryKey: ['projects', id],
    queryFn: async () => (await apiRequest<Envelope<Project>>('GET', `/projects/${id}`)).data,
  })
}

export function useCreateProject() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (name: string) => apiRequest<Envelope<Project>>('POST', '/projects', { project: { name } }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['projects'] }),
  })
}

export function useDeleteProject() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (id: number) => apiRequest<void>('DELETE', `/projects/${id}`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['projects'] }),
  })
}

export function useCreateDomain(projectId: number) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (host: string) =>
      apiRequest<Envelope<Domain>>('POST', `/projects/${projectId}/domains`, { domain: { host } }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['projects'] }),
  })
}

export function useVerifyDomain(projectId: number) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: ({ domainId, method }: { domainId: number; method: VerificationMethod }) =>
      apiRequest<Envelope<Domain>>('POST', `/domains/${domainId}/verify`, { method }),
    onSettled: () => queryClient.invalidateQueries({ queryKey: ['projects', projectId] }),
  })
}

export function useDeleteDomain(projectId: number) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (domainId: number) => apiRequest<void>('DELETE', `/domains/${domainId}`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['projects', projectId] }),
  })
}

export const FINISHED_STATUSES = ['completed', 'failed', 'cancelled']

export function useCrawls(projectId: number) {
  return useQuery({
    queryKey: ['projects', projectId, 'crawls'],
    queryFn: async () => (await apiRequest<Envelope<Crawl[]>>('GET', `/projects/${projectId}/crawls`)).data,
  })
}

export type NewCrawl = Partial<CrawlConfig> & { domain_id: number; terms_accepted?: boolean }

export function useCreateCrawl(projectId: number) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (crawl: NewCrawl) => apiRequest<Envelope<Crawl>>('POST', `/projects/${projectId}/crawls`, { crawl }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['projects', projectId, 'crawls'] }),
  })
}

// Polls every 3 s until the crawl and its audit finish.
export function useCrawl(id: number) {
  return useQuery({
    queryKey: ['crawls', id],
    queryFn: async () => (await apiRequest<Envelope<Crawl>>('GET', `/crawls/${id}`)).data,
    refetchInterval: (query) => {
      const crawl = query.state.data
      if (!crawl || !FINISHED_STATUSES.includes(crawl.status)) return 3000
      // A completed crawl keeps polling until its audit has finished.
      return crawl.status === 'completed' && ['pending', 'running'].includes(crawl.audit_status) ? 3000 : false
    },
  })
}

export function useCrawlAction(id: number) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (action: 'pause' | 'resume' | 'cancel') => apiRequest<Envelope<Crawl>>('POST', `/crawls/${id}/${action}`),
    onSuccess: (response) => queryClient.setQueryData(['crawls', id], response.data),
  })
}

type PagesResponse = Envelope<CrawlPage[]> & { meta: { next_cursor: number | null } }

export function useCrawlPages(id: number, statusFilter: string, refreshKey: unknown) {
  return useInfiniteQuery({
    queryKey: ['crawls', id, 'pages', statusFilter, refreshKey],
    initialPageParam: null as number | null,
    queryFn: async ({ pageParam }) => {
      const params = new URLSearchParams({ limit: '50' })
      if (statusFilter) params.set('filter[status_code]', statusFilter)
      if (pageParam) params.set('after', String(pageParam))
      return apiRequest<PagesResponse>('GET', `/crawls/${id}/pages?${params}`)
    },
    getNextPageParam: (last) => last.meta.next_cursor,
  })
}

type IssuesResponse = Envelope<IssueSummary[]> & { meta: { by_severity: Record<string, number> } }

export function useCrawlIssues(id: number, auditedAt: string | null) {
  return useQuery({
    queryKey: ['crawls', id, 'issues', auditedAt],
    queryFn: () => apiRequest<IssuesResponse>('GET', `/crawls/${id}/issues`),
    enabled: auditedAt !== null,
  })
}

type FindingsResponse = Envelope<Finding[]> & { meta: { next_cursor: number | null } }

export function useIssueFindings(id: number, checkKey: string) {
  return useInfiniteQuery({
    queryKey: ['crawls', id, 'issues', checkKey],
    initialPageParam: null as number | null,
    queryFn: ({ pageParam }) =>
      apiRequest<FindingsResponse>('GET', `/crawls/${id}/issues/${checkKey}?limit=50${pageParam ? `&after=${pageParam}` : ''}`),
    getNextPageParam: (last) => last.meta.next_cursor,
  })
}

export function usePageDetail(crawlId: number, pageId: number) {
  return useQuery({
    queryKey: ['crawls', crawlId, 'pages', pageId],
    queryFn: async () => (await apiRequest<Envelope<PageDetail>>('GET', `/crawls/${crawlId}/pages/${pageId}`)).data,
  })
}
