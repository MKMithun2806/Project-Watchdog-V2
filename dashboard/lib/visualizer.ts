import 'server-only';

import { readFileSync } from 'node:fs';
import { join } from 'node:path';

export const visualizerHtml = readFileSync(join(process.cwd(), 'lib/visualizer.raw.html'), 'utf8');

function escapeScriptJson(value: unknown) {
  return JSON.stringify(value ?? null)
    .replace(/<\/script>/gi, '<\\/script>')
    .replace(/\u2028/g, '\\u2028')
    .replace(/\u2029/g, '\\u2029');
}

export function buildVisualizerSrcDoc(graphData: unknown) {
  const safeJson = escapeScriptJson(graphData);
  return visualizerHtml.replace(
    '</script>',
    `\nloadGraph(${safeJson});\n</script>`
  );
}
