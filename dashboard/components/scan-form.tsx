'use client';

import Link from 'next/link';
import { FormEvent, useState } from 'react';

type ScanMode = 'normal' | 'stealth' | 'head';

type ResultState =
  | { ok: true; instanceId: string | null; message: string }
  | { ok: false; message: string };

export function ScanForm() {
  const [target, setTarget] = useState('');
  const [mode, setMode] = useState<ScanMode>('normal');
  const [exportJson, setExportJson] = useState(false);
  const [proxyFile, setProxyFile] = useState<string | null>(null);
  const [proxyFileName, setProxyFileName] = useState<string>('');
  const [pending, setPending] = useState(false);
  const [result, setResult] = useState<ResultState | null>(null);

  async function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setPending(true);
    setResult(null);

    try {
      const response = await fetch('/api/scan', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          target: target.trim(),
          mode,
          export_json: exportJson,
          proxy_lines: proxyFile ?? null,
        }),
      });

      const payload = (await response.json().catch(() => null)) as {
        instance_id?: string | null;
        message?: string;
        error?: string;
      } | null;

      if (!response.ok) {
        setResult({
          ok: false,
          message: payload?.error ?? payload?.message ?? 'Unable to launch scan.',
        });
        return;
      }

      setResult({
        ok: true,
        instanceId: payload?.instance_id ?? null,
        message: payload?.message ?? 'Scan launched. Check back in a few minutes.',
      });
      setTarget('');
      setMode('normal');
    } catch (error) {
      setResult({
        ok: false,
        message: error instanceof Error ? error.message : 'Unable to launch scan.',
      });
    } finally {
      setPending(false);
    }
  }

  return (
    <div className="space-y-4">
      <form onSubmit={onSubmit} className="border border-border bg-surface p-4">
        <div className="grid gap-4 md:grid-cols-[1fr_180px_auto] md:items-end">
          <label className="block">
            <span className="mb-2 block text-[11px] uppercase tracking-[0.22em] text-muted">Target</span>
            <input
              value={target}
              onChange={(event) => setTarget(event.target.value)}
              placeholder="example.com"
              required
              className="w-full border border-border bg-bg px-3 py-2 font-mono text-sm text-text outline-none placeholder:text-muted focus:border-accent"
            />
          </label>

          <label className="block">
            <span className="mb-2 block text-[11px] uppercase tracking-[0.22em] text-muted">Mode</span>
            <select
              value={mode}
              onChange={(event) => setMode(event.target.value as ScanMode)}
              className="w-full border border-border bg-bg px-3 py-2 font-mono text-sm text-text outline-none focus:border-accent"
            >
              <option value="normal">normal</option>
              <option value="stealth">stealth</option>
              <option value="head">head</option>
            </select>
          </label>

          <label className="flex items-center gap-2 text-[11px] uppercase tracking-[0.22em] text-muted cursor-pointer md:col-start-2 md:row-start-2">
            <input
              type="checkbox"
              checked={exportJson}
              onChange={(e) => setExportJson(e.target.checked)}
              className="accent-accent"
            />
            export json
          </label>

          <label className="block">
            <span className="mb-2 block text-[11px] uppercase tracking-[0.22em] text-muted">
              Proxy File <span className="text-muted">(optional, max 15 proxies)</span>
            </span>
            <input
              type="file"
              accept=".txt,text/plain"
              onChange={(e) => {
                const file = e.target.files?.[0];
                if (!file) {
                  setProxyFile(null);
                  setProxyFileName('');
                  return;
                }
                const reader = new FileReader();
                reader.onload = (ev) => {
                  const text = ev.target?.result as string;
                  const lines = text
                    .split('\n')
                    .map((l) => l.trim())
                    .filter((l) => l.length > 0)
                    .slice(0, 15);
                  setProxyFile(lines.join('\n'));
                  setProxyFileName(file.name);
                };
                reader.readAsText(file);
              }}
              className="w-full border border-border bg-bg px-3 py-2 font-mono text-sm text-text outline-none file:mr-3 file:border-0 file:bg-surface2 file:px-3 file:py-1 file:text-[11px] file:uppercase file:tracking-[0.22em] file:text-muted hover:file:text-text focus:border-accent"
            />
            {proxyFileName && (
              <span className="mt-1 block text-[11px] text-muted">{proxyFileName}</span>
            )}
          </label>

          <button
            type="submit"
            disabled={pending}
            className="border border-border bg-surface2 px-4 py-2 text-[11px] uppercase tracking-[0.22em] text-text transition-none hover:border-accent disabled:cursor-not-allowed disabled:text-muted md:col-start-3 md:row-start-2"
          >
            {pending ? 'Launching...' : 'Start Scan'}
          </button>
        </div>
      </form>

      {result ? (
        <div className="border border-border bg-surface p-4 font-mono text-sm text-text">
          <div className={result.ok ? 'text-accent' : 'text-danger'}>{result.message}</div>
          {result.ok && result.instanceId ? (
            <div className="mt-3 text-[11px] uppercase tracking-[0.22em] text-muted">
              instance_id: <span className="text-text">{result.instanceId}</span>
            </div>
          ) : null}
          {result.ok ? (
            <div className="mt-4">
              <Link href="/" className="text-[11px] uppercase tracking-[0.22em] text-accent underline underline-offset-2">
                back to reports
              </Link>
            </div>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}
