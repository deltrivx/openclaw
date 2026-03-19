import { extractTextCached } from "./message-extract.ts";

/**
 * Export chat history as markdown file.
 */
export function exportChatMarkdown(messages: unknown[], assistantName: string): void {
  const markdown = buildChatMarkdown(messages, assistantName);
  if (!markdown) {
    return;
  }
  const blob = new Blob([markdown], { type: "text/markdown" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = `chat-${assistantName}-${Date.now()}.md`;
  link.click();
  URL.revokeObjectURL(url);
}

export function buildChatMarkdown(messages: unknown[], assistantName: string): string | null {
  const history = Array.isArray(messages) ? messages : [];
  if (history.length === 0) {
    return null;
  }
  const lines: string[] = [`# 与 ${assistantName} 的聊天记录`, ""];
  for (const msg of history) {
    const m = msg as Record<string, unknown>;
    const role = m.role === "user" ? "你" : m.role === "assistant" ? assistantName : "工具";
    const content = extractTextCached(msg) ?? "";
    const ts = typeof m.timestamp === "number" ? new Date(m.timestamp).toISOString() : "";
    lines.push(`## ${role}${ts ? ` (${ts})` : ""}`, "", content, "");
  }
  return lines.join("\n");
}
