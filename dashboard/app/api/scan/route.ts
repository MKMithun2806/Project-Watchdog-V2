import { NextRequest, NextResponse } from 'next/server';

const allowedModes = new Set(['normal', 'stealth', 'head']);

export async function POST(request: NextRequest) {
  const apiUrl = process.env.WATCHDOG_API_URL;
  const apiKey = process.env.WATCHDOG_API_KEY;

  if (!apiUrl || !apiKey) {
    return NextResponse.json({ error: 'Watchdog API is not configured.' }, { status: 500 });
  }

  const body = (await request.json().catch(() => null)) as {
    target?: string;
    mode?: string;
    export_json?: boolean;
  } | null;

  const target = typeof body?.target === 'string' ? body.target.trim() : '';
  const modeInput = typeof body?.mode === 'string' ? body.mode : 'normal';
  const mode = modeInput.toLowerCase();
  const export_json = typeof body?.export_json === 'boolean' ? body.export_json : false;
  const proxy_lines =
    typeof body?.proxy_lines === 'string' && body.proxy_lines.trim().length > 0
      ? body.proxy_lines.trim()
      : null;

  if (!target) {
    return NextResponse.json({ error: 'Target is required.' }, { status: 400 });
  }

  if (!allowedModes.has(mode)) {
    return NextResponse.json({ error: 'Invalid scan mode.' }, { status: 400 });
  }

  const upstream = await fetch(apiUrl, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-api-key': apiKey,
    },
    body: JSON.stringify({ target, mode, export_json, proxy_lines }),
  });

  const raw = await upstream.text();
  let payload: Record<string, unknown> | null = null;

  if (raw) {
    try {
      payload = JSON.parse(raw) as Record<string, unknown>;
    } catch {
      payload = { message: raw };
    }
  }

  const instanceId =
    (payload?.instance_id as string | undefined) ??
    (payload?.instanceId as string | undefined) ??
    (payload?.execution_id as string | undefined) ??
    null;

  return NextResponse.json(
    {
      ...payload,
      instance_id: instanceId,
      export_json,
      has_proxies: proxy_lines !== null,
      message: payload?.message ?? 'Scan launched. Check back in a few minutes.',
    },
    { status: upstream.ok ? 200 : upstream.status }
  );
}
