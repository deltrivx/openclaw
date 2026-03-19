import type { Command } from "commander";
import { formatAuthChoiceChoicesForCli } from "../../commands/auth-choice-options.js";
import type { GatewayDaemonRuntime } from "../../commands/daemon-runtime.js";
import { CORE_ONBOARD_AUTH_FLAGS } from "../../commands/onboard-core-auth-flags.js";
import type {
  AuthChoice,
  GatewayAuthChoice,
  GatewayBind,
  NodeManagerChoice,
  ResetScope,
  SecretInputMode,
  TailscaleMode,
} from "../../commands/onboard-types.js";
import { setupWizardCommand } from "../../commands/onboard.js";
import { resolveManifestProviderOnboardAuthFlags } from "../../plugins/provider-auth-choices.js";
import { defaultRuntime } from "../../runtime.js";
import { formatDocsLink } from "../../terminal/links.js";
import { theme } from "../../terminal/theme.js";
import { runCommandWithRuntime } from "../cli-utils.js";

function resolveInstallDaemonFlag(
  command: unknown,
  opts: { installDaemon?: boolean },
): boolean | undefined {
  if (!command || typeof command !== "object") {
    return undefined;
  }
  const getOptionValueSource =
    "getOptionValueSource" in command ? command.getOptionValueSource : undefined;
  if (typeof getOptionValueSource !== "function") {
    return undefined;
  }

  // Commander doesn't support option conflicts natively; keep original behavior.
  // If --skip-daemon is explicitly passed, it wins.
  if (getOptionValueSource.call(command, "skipDaemon") === "cli") {
    return false;
  }
  if (getOptionValueSource.call(command, "installDaemon") === "cli") {
    return Boolean(opts.installDaemon);
  }
  return undefined;
}

const AUTH_CHOICE_HELP = formatAuthChoiceChoicesForCli({
  includeLegacyAliases: true,
  includeSkip: true,
});

const ONBOARD_AUTH_FLAGS = [
  ...CORE_ONBOARD_AUTH_FLAGS,
  ...resolveManifestProviderOnboardAuthFlags(),
] as const;

function pickOnboardProviderAuthOptionValues(
  opts: Record<string, unknown>,
): Partial<Record<string, string | undefined>> {
  return Object.fromEntries(
    ONBOARD_AUTH_FLAGS.map((flag) => [flag.optionKey, opts[flag.optionKey] as string | undefined]),
  );
}

export function registerOnboardCommand(program: Command) {
  const command = program
    .command("onboard")
    .description("交互式初始化网关、工作区与技能")
    .addHelpText(
      "after",
      () =>
        `\n${theme.muted("文档:")} ${formatDocsLink("/cli/onboard", "docs.openclaw.ai/cli/onboard")}\n`,
    )
    .option("--workspace <dir>", "代理工作区目录（默认：~/.openclaw/workspace）")
    .option(
      "--reset",
      "运行 onboard 前重置配置 + 凭据 + 会话（仅当 --reset-scope 为 full 时才清理工作区）",
    )
    .option("--reset-scope <scope>", "重置范围：config|config+creds+sessions|full")
    .option("--non-interactive", "无提示运行", false)
    .option(
      "--accept-risk",
      "确认已了解代理能力较强，授予完整系统访问存在风险（--non-interactive 必需）",
      false,
    )
    .option("--flow <flow>", "初始化流程：quickstart|advanced|manual")
    .option("--mode <mode>", "初始化模式：local|remote")
    .option("--auth-choice <choice>", `认证方式：${AUTH_CHOICE_HELP}`)
    .option(
      "--token-provider <id>",
      "Token provider id (non-interactive; used with --auth-choice token)",
    )
    .option("--token <token>", "Token value (non-interactive; used with --auth-choice token)")
    .option(
      "--token-profile-id <id>",
      "Auth profile id (non-interactive; default: <provider>:manual)",
    )
    .option("--token-expires-in <duration>", "Optional token expiry duration (e.g. 365d, 12h)")
    .option(
      "--secret-input-mode <mode>",
      "API key persistence mode: plaintext|ref (default: plaintext)",
    )
    .option("--cloudflare-ai-gateway-account-id <id>", "Cloudflare Account ID")
    .option("--cloudflare-ai-gateway-gateway-id <id>", "Cloudflare AI Gateway ID");

  for (const providerFlag of ONBOARD_AUTH_FLAGS) {
    command.option(providerFlag.cliOption, providerFlag.description);
  }

  command
    .option("--custom-base-url <url>", "自定义提供方 Base URL")
    .option("--custom-api-key <key>", "自定义提供方 API Key（可选）")
    .option("--custom-model-id <id>", "自定义提供方模型 ID")
    .option("--custom-provider-id <id>", "自定义提供方 ID（可选；默认自动推导）")
    .option(
      "--custom-compatibility <mode>",
      "自定义提供方 API 兼容模式：openai|anthropic（默认：openai）",
    )
    .option("--gateway-port <port>", "网关端口")
    .option("--gateway-bind <mode>", "网关监听：loopback|tailnet|lan|auto|custom")
    .option("--gateway-auth <mode>", "网关认证：token|password")
    .option("--gateway-token <token>", "网关 Token（token 认证）")
    .option(
      "--gateway-token-ref-env <name>",
      "Gateway token SecretRef env var name (token auth; e.g. OPENCLAW_GATEWAY_TOKEN)",
    )
    .option("--gateway-password <password>", "Gateway password (password auth)")
    .option("--remote-url <url>", "Remote Gateway WebSocket URL")
    .option("--remote-token <token>", "Remote Gateway token (optional)")
    .option("--tailscale <mode>", "Tailscale: off|serve|funnel")
    .option("--tailscale-reset-on-exit", "Reset tailscale serve/funnel on exit")
    .option("--install-daemon", "Install gateway service")
    .option("--no-install-daemon", "Skip gateway service install")
    .option("--skip-daemon", "Skip gateway service install")
    .option("--daemon-runtime <runtime>", "Daemon runtime: node|bun")
    .option("--skip-channels", "Skip channel setup")
    .option("--skip-skills", "Skip skills setup")
    .option("--skip-search", "Skip search provider setup")
    .option("--skip-health", "Skip health check")
    .option("--skip-ui", "Skip Control UI/TUI prompts")
    .option("--node-manager <name>", "Node manager for skills: npm|pnpm|bun")
    .option("--json", "Output JSON summary", false);

  command.action(async (opts, commandRuntime) => {
    await runCommandWithRuntime(defaultRuntime, async () => {
      const installDaemon = resolveInstallDaemonFlag(commandRuntime, {
        installDaemon: Boolean(opts.installDaemon),
      });
      const gatewayPort =
        typeof opts.gatewayPort === "string" ? Number.parseInt(opts.gatewayPort, 10) : undefined;
      const providerAuthOptionValues = pickOnboardProviderAuthOptionValues(
        opts as Record<string, unknown>,
      );
      await setupWizardCommand(
        {
          workspace: opts.workspace as string | undefined,
          nonInteractive: Boolean(opts.nonInteractive),
          acceptRisk: Boolean(opts.acceptRisk),
          flow: opts.flow as "quickstart" | "advanced" | "manual" | undefined,
          mode: opts.mode as "local" | "remote" | undefined,
          authChoice: opts.authChoice as AuthChoice | undefined,
          tokenProvider: opts.tokenProvider as string | undefined,
          token: opts.token as string | undefined,
          tokenProfileId: opts.tokenProfileId as string | undefined,
          tokenExpiresIn: opts.tokenExpiresIn as string | undefined,
          secretInputMode: opts.secretInputMode as SecretInputMode | undefined,
          ...providerAuthOptionValues,
          cloudflareAiGatewayAccountId: opts.cloudflareAiGatewayAccountId as string | undefined,
          cloudflareAiGatewayGatewayId: opts.cloudflareAiGatewayGatewayId as string | undefined,
          customBaseUrl: opts.customBaseUrl as string | undefined,
          customApiKey: opts.customApiKey as string | undefined,
          customModelId: opts.customModelId as string | undefined,
          customProviderId: opts.customProviderId as string | undefined,
          customCompatibility: opts.customCompatibility as "openai" | "anthropic" | undefined,
          gatewayPort:
            typeof gatewayPort === "number" && Number.isFinite(gatewayPort)
              ? gatewayPort
              : undefined,
          gatewayBind: opts.gatewayBind as GatewayBind | undefined,
          gatewayAuth: opts.gatewayAuth as GatewayAuthChoice | undefined,
          gatewayToken: opts.gatewayToken as string | undefined,
          gatewayTokenRefEnv: opts.gatewayTokenRefEnv as string | undefined,
          gatewayPassword: opts.gatewayPassword as string | undefined,
          remoteUrl: opts.remoteUrl as string | undefined,
          remoteToken: opts.remoteToken as string | undefined,
          tailscale: opts.tailscale as TailscaleMode | undefined,
          tailscaleResetOnExit: Boolean(opts.tailscaleResetOnExit),
          reset: Boolean(opts.reset),
          resetScope: opts.resetScope as ResetScope | undefined,
          installDaemon,
          daemonRuntime: opts.daemonRuntime as GatewayDaemonRuntime | undefined,
          skipChannels: Boolean(opts.skipChannels),
          skipSkills: Boolean(opts.skipSkills),
          skipSearch: Boolean(opts.skipSearch),
          skipHealth: Boolean(opts.skipHealth),
          skipUi: Boolean(opts.skipUi),
          nodeManager: opts.nodeManager as NodeManagerChoice | undefined,
          json: Boolean(opts.json),
        },
        defaultRuntime,
      );
    });
  });
}
