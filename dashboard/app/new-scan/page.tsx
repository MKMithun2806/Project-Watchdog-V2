import { ScanForm } from '@/components/scan-form';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export default function NewScanPage() {
  return (
    <section className="max-w-3xl space-y-4">
      <div className="border border-border bg-surface p-4">
        <h1 className="font-display text-xl uppercase tracking-[0.18em] text-text">New Scan</h1>
        <p className="mt-1 text-[11px] uppercase tracking-[0.24em] text-muted">
          trigger a recon run
        </p>
      </div>

      <ScanForm />
    </section>
  );
}
