import { formatCliCommand } from "../cli/command-format.js";
import { readConfigFileSnapshot } from "../config/config.js";
import { assertSupportedRuntime } from "../infra/runtime-guard.js";
import type { RuntimeEnv } from "../runtime.js";
import { defaultRuntime } from "../runtime.js";
import { resolveUserPath } from "../utils.js";
import { isDeprecatedAuthChoice, normalizeLegacyOnboardAuthChoice } from "./auth-choice-legacy.js";
import { DEFAULT_WORKSPACE, handleReset } from "./onboard-helpers.js";
import { runInteractiveSetup } from "./onboard-interactive.js";
import { runNonInteractiveSetup } from "./onboard-non-interactive.js";
import type { OnboardOptions, ResetScope } from "./onboard-types.js";
import { loadTranslator } from "../i18n/translate.js";

const t = loadTranslator("zh-CN", "onboard");

const VALID_RESET_SCOPES = new Set<ResetScope>(["config", "config+creds+sessions", "full"]);

export async function setupWizardCommand(
  opts: OnboardOptions,
  runtime: RuntimeEnv = defaultRuntime,
) {
  assertSupportedRuntime(runtime);
  const originalAuthChoice = opts.authChoice;
  const normalizedAuthChoice = normalizeLegacyOnboardAuthChoice(originalAuthChoice);
  if (opts.nonInteractive && isDeprecatedAuthChoice(originalAuthChoice)) {
    runtime.error(
      t("auth_choice_deprecated", { choice: String(originalAuthChoice) }),
    );
    runtime.exit(1);
    return;
  }
  // zh-CN i18n: keep these logs in English for now (low user impact).
  if (originalAuthChoice === "claude-cli") {
    runtime.log('Auth choice "claude-cli" is deprecated; using setup-token flow instead.');
  }
  if (originalAuthChoice === "codex-cli") {
    runtime.log('Auth choice "codex-cli" is deprecated; using OpenAI Codex OAuth instead.');
  }
  const flow = opts.flow === "manual" ? ("advanced" as const) : opts.flow;
  const normalizedOpts =
    normalizedAuthChoice === opts.authChoice && flow === opts.flow
      ? opts
      : { ...opts, authChoice: normalizedAuthChoice, flow };
  if (
    normalizedOpts.secretInputMode &&
    normalizedOpts.secretInputMode !== "plaintext" && // pragma: allowlist secret
    normalizedOpts.secretInputMode !== "ref" // pragma: allowlist secret
  ) {
    runtime.error(t("secret_input_mode_invalid"));
    runtime.exit(1);
    return;
  }

  if (normalizedOpts.resetScope && !VALID_RESET_SCOPES.has(normalizedOpts.resetScope)) {
    runtime.error(t("reset_scope_invalid"));
    runtime.exit(1);
    return;
  }

  if (normalizedOpts.nonInteractive && normalizedOpts.acceptRisk !== true) {
    runtime.error(
      [
        t("non_interactive_requires_risk_1"),
        t("non_interactive_requires_risk_2", { url: "https://docs.openclaw.ai/security" }),
        t("non_interactive_requires_risk_3", {
          cmd: formatCliCommand("openclaw onboard --non-interactive --accept-risk ..."),
        }),
      ].join("\n"),
    );
    runtime.exit(1);
    return;
  }

  if (normalizedOpts.reset) {
    const snapshot = await readConfigFileSnapshot();
    const baseConfig = snapshot.valid ? snapshot.config : {};
    const workspaceDefault =
      normalizedOpts.workspace ?? baseConfig.agents?.defaults?.workspace ?? DEFAULT_WORKSPACE;
    const resetScope: ResetScope = normalizedOpts.resetScope ?? "config+creds+sessions";
    await handleReset(resetScope, resolveUserPath(workspaceDefault), runtime);
  }

  if (process.platform === "win32") {
    runtime.log(
      [
        t("windows_detected_1"),
        t("windows_detected_2"),
        t("windows_detected_3"),
        t("windows_detected_4", { url: "https://docs.openclaw.ai/windows" }),
      ].join("\n"),
    );
  }

  if (normalizedOpts.nonInteractive) {
    await runNonInteractiveSetup(normalizedOpts, runtime);
    return;
  }

  await runInteractiveSetup(normalizedOpts, runtime);
}

export const onboardCommand = setupWizardCommand;

export type { OnboardOptions } from "./onboard-types.js";
export type { OnboardOptions as SetupWizardOptions } from "./onboard-types.js";
