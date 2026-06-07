import Link from 'next/link';

export default function NotFound() {
  return (
    <section className="border border-border bg-surface p-6 font-mono text-sm text-muted">
      <div className="text-text">report not found</div>
      <p className="mt-2">the requested scan does not exist.</p>
      <Link
        href="/"
        className="mt-4 inline-block text-[11px] uppercase tracking-[0.22em] text-accent underline underline-offset-2"
      >
        back to reports
      </Link>
    </section>
  );
}
