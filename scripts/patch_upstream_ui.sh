#!/usr/bin/env bash
set -euo pipefail

UPSTREAM_ROOT="${1:?usage: patch_upstream_ui.sh <path-to-upstream-openclaw> }"

UI_STORAGE="$UPSTREAM_ROOT/ui/src/ui/storage.ts"
I18N_TRANSLATE="$UPSTREAM_ROOT/ui/src/i18n/lib/translate.ts"

if [[ ! -f "$UI_STORAGE" ]]; then
  echo "Missing expected file: $UI_STORAGE" >&2
  exit 1
fi
if [[ ! -f "$I18N_TRANSLATE" ]]; then
  echo "Missing expected file: $I18N_TRANSLATE" >&2
  exit 1
fi

# 1) Default UI settings locale to zh-CN (so app boot sets i18n quickly)
# Insert `locale: "zh-CN",` into defaults object if not present.
if ! grep -q "locale: \"zh-CN\"" "$UI_STORAGE"; then
  # add before closing brace of defaults object (first occurrence of "borderRadius: 50,")
  perl -0777 -i -pe 's/(borderRadius:\s*50,\s*)\n\s*};/$1\n    locale: "zh-CN",\n  };/s' "$UI_STORAGE"
fi

# 2) Force i18n initial locale to zh-CN when nothing is saved
# Replace resolveInitialLocale() behavior: if no saved locale, return zh-CN.
if ! grep -q "return \"zh-CN\";" "$I18N_TRANSLATE"; then
  perl -0777 -i -pe 's/\n\s*const language =\n\s*typeof globalThis\.navigator\?\.language[\s\S]*?return resolveNavigatorLocale\(language \?\? ""\);/\n    return "zh-CN";\n/s' "$I18N_TRANSLATE"
fi

# Sanity checks
if ! grep -q "locale: \"zh-CN\"" "$UI_STORAGE"; then
  echo "Failed to set default locale in $UI_STORAGE" >&2
  exit 1
fi
if ! grep -q "return \"zh-CN\";" "$I18N_TRANSLATE"; then
  echo "Failed to set default initial locale in $I18N_TRANSLATE" >&2
  exit 1
fi

echo "OK: patched upstream UI to default zh-CN"
