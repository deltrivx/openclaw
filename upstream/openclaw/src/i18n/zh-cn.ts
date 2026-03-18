import { loadTranslator } from "../../../scripts/i18n/translate.js";

export function getZhCnOnboardTranslator() {
  // Reads from translations/zh-CN/onboard.json at runtime.
  return loadTranslator("zh-CN", "onboard");
}
