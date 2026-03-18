import fs from "node:fs";
import path from "node:path";

export type Dict = Record<string, string>;

function loadJson(p: string): any {
  return JSON.parse(fs.readFileSync(p, "utf-8"));
}

export function format(template: string, vars: Record<string, string | number>): string {
  return template.replace(/\{(\w+)\}/g, (_, k) => String(vars[k] ?? `{${k}}`));
}

export function createTranslator(dict: Dict) {
  return function t(key: string, vars?: Record<string, string | number>): string {
    const msg = dict[key] ?? key;
    return vars ? format(msg, vars) : msg;
  };
}

export function loadTranslator(locale: string, namespace: string) {
  const file = path.resolve(process.cwd(), "translations", locale, `${namespace}.json`);
  const dict = loadJson(file) as Dict;
  return createTranslator(dict);
}
