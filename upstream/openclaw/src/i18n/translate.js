// Minimal runtime JS wrapper to avoid TypeScript toolchain requirements.
// Loads repo-local translations from /opt/openclaw-enhanced/translations when inside the image,
// and from ./translations when used in-repo.

import fs from "node:fs";
import path from "node:path";

function loadJson(p) {
  return JSON.parse(fs.readFileSync(p, "utf-8"));
}

function format(template, vars) {
  return template.replace(/\{(\w+)\}/g, (_, k) => String((vars && vars[k]) ?? `{${k}}`));
}

export function createTranslator(dict) {
  return function t(key, vars) {
    const msg = dict[key] ?? key;
    return vars ? format(msg, vars) : msg;
  };
}

export function loadTranslator(locale, namespace) {
  const roots = [
    // inside our image
    "/opt/openclaw-enhanced/translations",
    // in repo
    path.resolve(process.cwd(), "translations"),
  ];

  for (const root of roots) {
    const file = path.resolve(root, locale, `${namespace}.json`);
    if (fs.existsSync(file)) {
      return createTranslator(loadJson(file));
    }
  }
  return createTranslator({});
}
