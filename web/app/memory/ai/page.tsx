"use client";

import { Suspense, useEffect, useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import {
  kk_ai_consume_and_run,
  kk_ai_usage_get,
  kk_memory_list,
  type AiUsage,
  type AiExpandResult,
} from "@/lib/kk/api";

function AiPanel() {
  const sp = useSearchParams();
  const fromMemory = sp.get("from") === "memory";
  const [text, setText] = useState(() => {
    if (typeof window === "undefined") return "";
    try {
      const draft = sessionStorage.getItem("kk.ai.draft");
      if (draft) {
        sessionStorage.removeItem("kk.ai.draft");
        return draft;
      }
    } catch {
      /* ignore */
    }
    return "";
  });
  const [quota, setQuota] = useState<AiUsage | null>(null);
  const [result, setResult] = useState<AiExpandResult | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [pickId, setPickId] = useState("");

  useEffect(() => {
    void kk_ai_usage_get().then(setQuota);
    if (fromMemory) {
      void kk_memory_list().then((items) => {
        if (items[0]) {
          setPickId(items[0].id);
          setText(items[0].originalWords);
        }
      });
    }
  }, [fromMemory]);

  const run = async () => {
    if (!text.trim() || !quota || quota.remaining <= 0) return;
    setBusy(true);
    setError(null);
    try {
      const r = await kk_ai_consume_and_run({ text: text.trim() });
      setResult(r);
      setQuota(await kk_ai_usage_get());
    } catch (e) {
      setError(e instanceof Error ? e.message : "failed");
    } finally {
      setBusy(false);
    }
  };

  const locked = quota !== null && quota.remaining <= 0;

  return (
    <main className="mx-auto min-h-screen max-w-2xl p-4 pb-24">
      <div className="mb-4 flex items-center justify-between">
        <Link href="/memory" className="text-sm text-rose">
          ← 記憶空間
        </Link>
        <h1 className="text-lg">{fromMemory ? "跟原話搵計劃" : "手打提議"}</h1>
        <span />
      </div>
      <p className="mb-3 text-xs text-ink-soft">
        AI 剩餘 {quota ? `${quota.remaining}/${quota.limit}` : "…"} · 每次用 1 次 · 只處理你提交嘅文字
      </p>
      {locked && (
        <p className="mb-3 rounded-xl bg-rose-soft px-3 py-2 text-sm text-rose">
          本月配額已用完（鎖定）
        </p>
      )}
      {fromMemory && (
        <p className="mb-2 text-xs text-ink-soft">已載入記憶原話（可改）· pick={pickId || "—"}</p>
      )}
      <textarea
        value={text}
        onChange={(e) => setText(e.target.value)}
        rows={6}
        disabled={locked}
        placeholder="輸入想整理／諗計劃嘅內容…"
        className="w-full rounded-2xl border border-line bg-cream px-4 py-3 outline-none focus:border-rose disabled:opacity-50"
      />
      <button
        type="button"
        disabled={busy || locked || !text.trim()}
        onClick={() => void run()}
        className="mt-3 w-full rounded-2xl bg-rose py-3 font-medium text-white disabled:opacity-40"
      >
        {busy ? "諗緊…" : "用 1 次配額 · 整理 + 諗計劃"}
      </button>
      {error && <p className="mt-3 text-sm text-rose">{error}</p>}
      {result && (
        <div className="mt-4 space-y-3">
          <pre className="whitespace-pre-wrap rounded-2xl bg-surface p-4 text-sm shadow-sm">
            {result.organized}
          </pre>
          <pre className="whitespace-pre-wrap rounded-2xl bg-surface p-4 text-sm shadow-sm">
            {result.plan}
          </pre>
        </div>
      )}
    </main>
  );
}

export default function MemoryAiPage() {
  return (
    <Suspense fallback={<main className="p-8 text-center">載入…</main>}>
      <AiPanel />
    </Suspense>
  );
}
