import type { Metadata } from 'next';
import type { ReactNode } from 'react';
import Link from 'next/link';

import './globals.css';

export const metadata: Metadata = {
  title: 'Watchdog Dashboard',
  description: 'Security scan reports and scan launcher for Project Watchdog V2.',
};

export default function RootLayout({
  children,
}: Readonly<{
  children: ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="min-h-screen bg-bg text-text">
        <div className="flex min-h-screen flex-col">
          <header className="sticky top-0 z-40 border-b border-border bg-bg">
            <div className="mx-auto flex h-14 w-full max-w-7xl items-center gap-3 px-4 text-[11px] uppercase tracking-[0.24em] sm:px-6">
              <Link
                href="/"
                className="font-display text-sm uppercase tracking-[0.28em] text-accent"
              >
                watchdog
              </Link>
              <span className="text-muted">-</span>
              <Link href="/" className="text-muted hover:text-text">
                reports
              </Link>
              <span className="text-muted">-</span>
              <Link href="/new-scan" className="text-muted hover:text-text">
                new scan
              </Link>
            </div>
          </header>

          <main className="mx-auto w-full max-w-7xl flex-1 px-4 py-6 sm:px-6">
            {children}
          </main>
        </div>
      </body>
    </html>
  );
}
