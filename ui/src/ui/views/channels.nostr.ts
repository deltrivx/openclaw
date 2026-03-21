import { html, nothing } from "lit";
import { formatRelativeTimestamp } from "../format.ts";
import type { NostrAccountStatus, NostrStatus } from "../types.ts";
import { renderChannelConfigSection } from "./channels.config.ts";
import { renderNostrProfileForm } from "./channels.nostr-profile-form.ts";
import type { ChannelsProps } from "./channels.types.ts";

function truncatePubkey(pubkey?: string | null) {
  if (!pubkey) {
    return "n/a";
  }
  if (pubkey.length <= 18) {
    return pubkey;
  }
  return `${pubkey.slice(0, 8)}…${pubkey.slice(-8)}`;
}

export function renderNostrCard(params: {
  props: ChannelsProps;
  nostr?: NostrStatus | null;
  accountCountLabel: unknown;
}) {
  const { props, nostr, accountCountLabel } = params;
  const nostrAccounts = Array.isArray(nostr?.accounts) ? nostr!.accounts : [];
  const hasMultipleAccounts = nostrAccounts.length > 1;

  const summaryConfigured = nostrAccounts.some((account) => account.configured);
  const summaryRunning = nostrAccounts.some((account) => account.running);
  const summaryPublicKey = nostrAccounts[0]?.publicKey ?? nostr?.publicKey ?? null;
  const summaryLastStartAt = nostrAccounts[0]?.lastStartAt ?? nostr?.lastStartAt ?? null;
  const summaryLastError = nostrAccounts.find((account) => account.lastError)?.lastError ?? nostr?.lastError ?? null;

  const renderAccountCard = (account: NostrAccountStatus) => {
    const name = account.profile?.name?.trim();
    const displayName = account.profile?.displayName?.trim();
    const about = account.profile?.about?.trim();
    return html`
      <div class="card" style="margin-top: 12px;">
        <div class="card-title monospace">${truncatePubkey(account.publicKey)}</div>
        <div class="status-list" style="margin-top: 12px;">
          <div>
            <span class="label">已配置</span>
            <span>${account.configured ? "是" : "否"}</span>
          </div>
          <div>
            <span class="label">运行中</span>
            <span>${account.running ? "是" : "否"}</span>
          </div>
          <div>
            <span class="label">最近启动</span>
            <span>${account.lastStartAt ? formatRelativeTimestamp(account.lastStartAt) : "不适用"}</span>
          </div>
          ${name ? html`<div><span class="label">名称</span><span>${name}</span></div>` : nothing}
          ${
            displayName
              ? html`<div><span class="label">显示名称</span><span>${displayName}</span></div>`
              : nothing
          }
          ${
            about
              ? html`<div><span class="label">简介</span><span style="max-width: 300px; overflow: hidden; text-overflow: ellipsis;">${about}</span></div>`
              : nothing
          }
        </div>
        ${
          account.lastError
            ? html`<div class="callout danger" style="margin-top: 12px;">${account.lastError}</div>`
            : nothing
        }
      </div>
    `;
  };

  const renderProfileSection = () => {
    if (!nostr) {
      return nothing;
    }
    return html`
      <div style="margin-top: 16px;">
        ${renderNostrProfileForm({ props, nostr })}
      </div>
    `;
  };

  return html`
    <div class="card">
      <div class="card-title">Nostr</div>
      <div class="card-sub">通过 Nostr 中继进行去中心化私信（NIP-04）。</div>
      ${accountCountLabel}

      ${
        hasMultipleAccounts
          ? html`
              <div class="account-card-list">
                ${nostrAccounts.map((account) => renderAccountCard(account))}
              </div>
            `
          : html`
              <div class="status-list" style="margin-top: 16px;">
                <div>
                  <span class="label">已配置</span>
                  <span>${summaryConfigured ? "是" : "否"}</span>
                </div>
                <div>
                  <span class="label">运行中</span>
                  <span>${summaryRunning ? "是" : "否"}</span>
                </div>
                <div>
                  <span class="label">公钥</span>
                  <span class="monospace" title="${summaryPublicKey ?? ""}">${truncatePubkey(summaryPublicKey)}</span>
                </div>
                <div>
                  <span class="label">最近启动</span>
                  <span>${summaryLastStartAt ? formatRelativeTimestamp(summaryLastStartAt) : "不适用"}</span>
                </div>
              </div>
            `
      }

      ${
        summaryLastError
          ? html`<div class="callout danger" style="margin-top: 12px;">${summaryLastError}</div>`
          : nothing
      }

      ${renderProfileSection()}

      ${renderChannelConfigSection({ channelId: "nostr", props })}

      <div class="row" style="margin-top: 12px;">
        <button class="btn" @click=${() => props.onRefresh(false)}>刷新</button>
      </div>
    </div>
  `;
}
