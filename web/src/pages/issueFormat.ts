import type { Severity } from '../api/types'

export const SEVERITY_LABELS: Record<Severity, string> = { error: 'Errores', warning: 'Avisos', notice: 'Notas' }
export const SEVERITY_BADGES: Record<Severity, string> = { error: 'Error', warning: 'Aviso', notice: 'Nota' }

// Short, readable rendering of a finding's details ({ status: 404 } → "status: 404").
export function formatDetails(details: Record<string, unknown>) {
  return Object.entries(details)
    .map(([key, value]) => `${key}: ${Array.isArray(value) ? value.slice(0, 3).join(', ') + (value.length > 3 ? '…' : '') : String(value)}`)
    .join(' · ')
}
