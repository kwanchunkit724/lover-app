"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  getMoodForToday,
  kk_ai_usage_get,
  kk_memory_list,
  type AiUsage,
  type MemoryCategory,
  type MemoryItem,
} from "@/lib/kk/api";

const CATS: Array<"全部" | MemoryCategory> = ["全部", "日常", "約會", "計劃", "其他"];

export default function MemoryPage() {
  const router = useRouter();
  const [items, setItems] = useState<MemoryItem[]>([]);
  const [filter, setFilter] = useState<(typeof CATS)[number]>("全部");
  const [quota, setQuota] = useState<AiUsage | null>(null);

  useEffect(() => {
    if (!getMoodForToday()) {
      router.replace("/mood");
      return;
    }
    void kk_memory_list().then(setItems);
    void kk_ai_usage_get().then(setQuota);
  }, [router]);

  const shown =
    filter === "全部" ? items : items.filter((m) => m.category === filter);
  const locked = quota !== null && quota.remaining <= 0;

  return (
    <main className="mx-auto min-h-screen max-w-2xl pb-24">
      <header className="border-b border-line bg-surface/90 px-4 py-4 backdrop-blur">
        <h1 className="text-lg">
          <span className="kao mr-1">♡</span>記憶空間
        </h1>
        <p className="text-xs text-ink-soft">Memory space · 共享回憶</p>
      </header>

      <div className="space-y-4 p-4">
        <div className="grid grid-cols-2 gap-2">
          <Link
            href={locked ? "#" : "/memory/ai"}
            className={`rounded-2xl border border-line bg-cream px-3 py-3 text-center text-sm ${
              locked ? "pointer-events-none opacity-40" : ""
            }`}
          >
            <div>✨ 手打提議</div>
            <div className="text-[10px] text-ink-soft">Type an idea</div>
          </Link>
          <Link
            href={locked ? "#" : "/memory/ai?from=memory"}
            className={`rounded-2xl border border-line bg-cream px-3 py-3 text-center text-sm ${
              locked ? "pointer-events-none opacity-40" : ""
            }`}
          >
            <div>📝 跟原話搵計劃</div>
            <div className="text-[10px] text-ink-soft">From memory</div>
          </Link>
        </div>
        <p className="text-center text-xs text-ink-soft">
          AI 剩餘 {quota ? `${quota.remaining}/${quota.limit}` : "…"}
          {locked ? " · 已用完（鎖定）" : ""}
        </p>

        <div className="flex flex-wrap gap-1">
          {CATS.map((c) => (
            <button
              key={c}
              type="button"
              onClick={() => setFilter(c)}
              className={`rounded-full px-3 py-1 text-xs ${
                filter === c ? "bg-rose text-white" : "bg-cream-deep text-ink-soft"
              }`}
            >
              {c}
            </button>
          ))}
        </div>

        {shown.length === 0 ? (
          <div className="py-16 text-center">
            <p className="kao text-2xl">(｡•́︿•̀｡)</p>
            <p className="mt-2 text-sm text-ink-soft">仲未有記憶 · 由聊天合併或手動新增啦</p>
          </div>
        ) : (
          shown.map((m) => (
            <article key={m.id} className="rounded-2xl border border-line bg-surface p-4 shadow-sm">
              <div className="flex gap-3">
                <div className="kao shrink-0 text-sm">(´∀｀)</div>
                <div className="min-w-0 flex-1">
                  <h3 className="font-medium">{m.title}</h3>
                  <p className="mt-1 text-sm text-ink-soft">「{m.originalWords}」</p>
                  {m.note && <p className="mt-1 text-xs text-ink">計劃摘要：{m.note}</p>}
                  {m.sourceMessage && (
                    <p className="mt-1 text-[11px] text-ink-soft">來源訊息（48h 後清除）</p>
                  )}
                  <div className="mt-2 flex items-center gap-2">
                    <span className="rounded-full bg-rose-soft px-2 py-0.5 text-[11px] text-rose">
                      {m.category}
                    </span>
                    <span className="text-[11px] text-ink-soft">
                      {m.createdAt.slice(0, 10)}
                    </span>
                  </div>
                </div>
              </div>
            </article>
          ))
        )}
      </div>

      <Link
        href="/memory/new"
        className="fixed bottom-20 right-4 z-30 flex h-12 w-12 items-center justify-center rounded-full bg-rose text-2xl text-white shadow-lg"
        aria-label="新增記憶"
      >
        ＋
      </Link>
    </main>
  );
}
