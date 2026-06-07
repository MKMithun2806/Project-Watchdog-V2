import 'server-only';

import { SUPABASE_BUCKET, supabase } from '@/lib/supabase';

export type ScanRecord = {
  id: string;
  target: string;
  scan_date: string;
  status: string;
  graph_url?: string | null;
  report_url?: string | null;
  summary_url?: string | null;
  json_url?: string | null;
  notes?: string | null;
};

export function normalizeStoragePath(path: string) {
  return path.replace(new RegExp(`^${SUPABASE_BUCKET}/`), '');
}

export async function getSignedUrl(path: string | null | undefined) {
  if (!path) return null;

  const { data, error } = await supabase.storage
    .from(SUPABASE_BUCKET)
    .createSignedUrl(normalizeStoragePath(path), 3600);

  if (error || !data?.signedUrl) {
    return null;
  }

  return data.signedUrl;
}

export async function fetchSignedText(path: string | null | undefined) {
  try {
    const signedUrl = await getSignedUrl(path);
    if (!signedUrl) return null;

    const response = await fetch(signedUrl, { cache: 'no-store' });
    if (!response.ok) return null;

    return response.text();
  } catch {
    return null;
  }
}

export async function fetchSignedJson<T>(path: string | null | undefined) {
  try {
    const signedUrl = await getSignedUrl(path);
    if (!signedUrl) return null;

    const response = await fetch(signedUrl, { cache: 'no-store' });
    if (!response.ok) return null;

    return (await response.json()) as T;
  } catch {
    return null;
  }
}

export async function getScans() {
  const { data, error } = await supabase
    .from('recon_scans')
    .select('*')
    .order('scan_date', { ascending: false });

  if (error) {
    throw error;
  }

  return (data ?? []) as ScanRecord[];
}

export async function getScan(id: string) {
  const { data, error } = await supabase
    .from('recon_scans')
    .select('*')
    .eq('id', id)
    .maybeSingle();

  if (error) {
    throw error;
  }

  return (data ?? null) as ScanRecord | null;
}

export function formatScanDate(scanDate: string) {
  return new Intl.DateTimeFormat('en-US', {
    dateStyle: 'medium',
    timeStyle: 'short',
    timeZone: 'UTC',
  }).format(new Date(scanDate));
}

export function statusTone(status: string) {
  const value = status.toLowerCase();
  if (value === 'completed') {
    return 'teal';
  }
  if (value === 'running') {
    return 'amber';
  }
  if (value === 'failed') {
    return 'red';
  }
  return 'muted';
}
