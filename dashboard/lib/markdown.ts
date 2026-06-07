import 'server-only';

import { marked } from 'marked';

marked.setOptions({
  gfm: true,
  breaks: true,
});

export async function renderMarkdown(markdown: string) {
  return String(await marked.parse(markdown || ''));
}
