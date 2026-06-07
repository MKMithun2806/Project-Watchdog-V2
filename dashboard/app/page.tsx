import Link from 'next/link';

import { formatScanDate, getScans, statusTone, type ScanRecord } from '@/lib/watchdog';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

function statusStyles(status: string) {
  const tone = statusTone(status);
  if (tone === 'teal') {
    return 'border-accent text-accent';
  }
  if (tone === 'amber') {
    return 'border-warn text-warn';
  }
  if (tone === 'red') {
    return 'border-danger text-danger';
  }
  return 'border-border text-muted';
}

export default async function ReportsPage() {
  let scans: ScanRecord[] = [];
  let errorMessage: string | null = null;

  try {
    scans = await getScans();
  } catch (error) {
    errorMessage = error instanceof Error ? error.message : 'Unable to load scans.';
  }

  return (
    <section className="space-y-4">
      <div className="border border-border bg-surface p-4">
        <div className="flex items-end justify-between gap-4">
          <div>
            <h1 className="font-display text-xl uppercase tracking-[0.18em] text-text">Reports</h1>
            <p className="mt-1 text-[11px] uppercase tracking-[0.24em] text-muted">
              security scan history
            </p>
          </div>
          <div className="font-mono text-[11px] uppercase tracking-[0.22em] text-muted">
            {scans.length} scans
          </div>
        </div>
      </div>

      {errorMessage ? (
        <div className="border border-danger bg-surface p-4 font-mono text-sm text-danger">
          {errorMessage}
        </div>
      ) : null}

      {!errorMessage && scans.length === 0 ? (
        <div className="border border-border bg-surface p-6 font-mono text-sm text-muted">
          no scans yet
        </div>
      ) : null}

      {!errorMessage && scans.length > 0 ? (
        <div className="overflow-x-auto border border-border bg-surface">
          <table className="min-w-full border-collapse font-mono text-sm">
            <thead className="border-b border-border text-[11px] uppercase tracking-[0.2em] text-muted">
              <tr>
                <th className="px-4 py-3 text-left font-normal">Target</th>
                <th className="px-4 py-3 text-left font-normal">Date</th>
                <th className="px-4 py-3 text-left font-normal">Status</th>
                <th className="px-4 py-3 text-left font-normal">Actions</th>
              </tr>
            </thead>
            <tbody>
              {scans.map((scan) => (
                <tr key={scan.id} className="border-b border-border last:border-0 hover:bg-surface2">
                  <td className="px-4 py-3">
                    <Link href={`/reports/${scan.id}`} className="text-text hover:text-accent">
                      {scan.target}
                    </Link>
                  </td>
                  <td className="px-4 py-3 text-muted">{formatScanDate(scan.scan_date)}</td>
                  <td className="px-4 py-3">
                    <span
                      className={`inline-flex border px-2 py-1 text-[10px] uppercase tracking-[0.2em] ${statusStyles(scan.status)}`}
                    >
                      {scan.status}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    <Link
                      href={`/reports/${scan.id}`}
                      className="text-[11px] uppercase tracking-[0.22em] text-accent underline underline-offset-2"
                    >
                      open
                    </Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : null}
    </section>
  );
}
