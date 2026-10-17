import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ApiError, apiRequest, setCsrfToken } from './client'
import type { Domain, Envelope, Project, User } from './types'

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
    mutationFn: (domainId: number) =>
      apiRequest<Envelope<Domain>>('POST', `/domains/${domainId}/verify`, { method: 'dns_txt' }),
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
