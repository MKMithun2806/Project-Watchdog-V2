'use client';

import { useState } from 'react';

import { GraphFrame } from '@/components/graph-frame';

type ReportTabsProps = {
  summaryHtml: string;
  reportHtml: string;
  graphSrcDoc: string | null;
};

type TabKey = 'summary' | 'report' | 'graph';

const tabs: Array<{ key: TabKey; label: string }> = [
  { key: 'summary', label: 'Summary' },
  { key: 'report', label: 'Raw Report' },
  { key: 'graph', label: 'Attack Graph' },
];

export function ReportTabs({ summaryHtml, reportHtml, graphSrcDoc }: ReportTabsProps) {
  const [activeTab, setActiveTab] = useState<TabKey>('summary');

  return (
    <section
      className="flex flex-col border border-border bg-surface"
      style={{ height: 'calc(100vh - 220px)' }}
    >
      <div className="sticky top-0 z-10 flex border-b border-border bg-surface">
        {tabs.map((tab) => {
          const active = activeTab === tab.key;
          return (
            <button
              key={tab.key}
              type="button"
              onClick={() => setActiveTab(tab.key)}
              className={[
                'border-r border-border px-4 py-3 text-[11px] uppercase tracking-[0.24em] transition-none',
                active ? 'bg-surface2 text-text' : 'text-muted hover:text-text',
              ].join(' ')}
            >
              {tab.label}
            </button>
          );
        })}
      </div>

      <div className="flex-1 overflow-hidden" style={{ minHeight: 0 }}>
        {activeTab === 'summary' ? (
          <div className="markdown-content h-full overflow-auto p-4" dangerouslySetInnerHTML={{ __html: summaryHtml }} />
        ) : null}

        {activeTab === 'report' ? (
          <div className="markdown-content h-full overflow-auto p-4" dangerouslySetInnerHTML={{ __html: reportHtml }} />
        ) : null}

        {activeTab === 'graph' ? (
          graphSrcDoc ? (
            <div className="h-full w-full">
              <GraphFrame srcDoc={graphSrcDoc} />
            </div>
          ) : (
            <div className="flex h-full items-center justify-center p-6 text-[11px] uppercase tracking-[0.22em] text-muted">
              attack graph unavailable
            </div>
          )
        ) : null}
      </div>
    </section>
  );
}
