// Adds request headers from ~/.agent-secrets/browser-auth.json, read on every request so
// credentials supplied after the browser starts take effect at once. Each rule applies only
// to URLs matching its pattern, so a credential never reaches other hosts.
//
// [{ "urlPattern": "^https://example\\.com/", "header": "authorization",
//    "prefix": "Bearer ", "valueFile": "~/.agent-secrets/example-token" }]
import { readFileSync } from 'node:fs';
import { homedir } from 'node:os';

type Rule = { urlPattern: string; header: string; prefix?: string; valueFile: string };

const expand = (p: string) => p.replace(/^~(?=\/)/, homedir());

function read(path: string): string {
  try {
    return readFileSync(expand(path), 'utf8').trim();
  } catch {
    return '';
  }
}

export default async ({ page }) => {
  await page.context().route('**/*', route => {
    const url = route.request().url();
    const headers = route.request().headers();
    let rules: Rule[] = [];
    try {
      rules = JSON.parse(read('~/.agent-secrets/browser-auth.json') || '[]');
    } catch {}
    for (const rule of rules) {
      if (!new RegExp(rule.urlPattern).test(url)) continue;
      const value = read(rule.valueFile);
      if (value) headers[rule.header.toLowerCase()] = (rule.prefix ?? '') + value;
    }
    route.continue({ headers });
  });
};
