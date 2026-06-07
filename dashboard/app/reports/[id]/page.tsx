import { notFound } from 'next/navigation';

import { ReportTabs } from '@/components/report-tabs';
import { renderMarkdown } from '@/lib/markdown';
import { buildVisualizerSrcDoc } from '@/lib/visualizer';
import { fetchSignedJson, fetchSignedText, formatScanDate, getScan, getSignedUrl } from '@/lib/watchdog';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

type ReportPageProps = {
  params: {
    id: string;
  };
};

function fallbackMarkdown(message: string) {
  return `<p>${message}</p>`;
}

export default async function ReportPage({ params }: ReportPageProps) {
  const { id } = params;
  const scan = await getScan(id);

  if (!scan) {
    notFound();
  }

  const [summaryText, reportText, graphJson, jsonSignedUrl] = await Promise.all([
    fetchSignedText(scan.summary_url ?? null),
    fetchSignedText(scan.report_url ?? null),
    fetchSignedJson<Record<string, unknown>>(scan.graph_url ?? null),
    getSignedUrl(scan.json_url ?? null),
  ]);

  const summaryHtml = summaryText
    ? await renderMarkdown(summaryText)
    : fallbackMarkdown('summary unavailable');

  const reportHtml = reportText
    ? await renderMarkdown(reportText)
    : fallbackMarkdown('report unavailable');

  const graphSrcDoc = graphJson ? buildVisualizerSrcDoc(graphJson) : null;

  return (
    <section className="flex flex-col gap-4">
      <div className="border border-border bg-surface p-4">
        <div className="flex flex-wrap items-end justify-between gap-4">
          <div>
            <h1 className="font-display text-xl uppercase tracking-[0.18em] text-text">
              {scan.target}
            </h1>
            <div className="mt-2 flex flex-wrap gap-4 text-[11px] uppercase tracking-[0.22em] text-muted">
              <span>date: {formatScanDate(scan.scan_date)}</span>
              <span>status: {scan.status}</span>
              <span>id: {scan.id}</span>
            </div>
          </div>
          {jsonSignedUrl && (
            <a
              href={jsonSignedUrl}
              download="report.json"
              className="border border-border px-3 py-2 text-[11px] uppercase tracking-[0.22em] text-muted hover:border-accent hover:text-accent"
            >
              export json
            </a>
          )}
        </div>
      </div>

      <div className="min-h-0 flex-1">
        <ReportTabs summaryHtml={summaryHtml} reportHtml={reportHtml} graphSrcDoc={graphSrcDoc} />
      </div>
    </section>
  );
}
