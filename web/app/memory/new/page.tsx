"use client";

import { Suspense, useMemo, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import Link from "next/link";
import { kk_memory_create, kk_memory_from_chat, type MemoryCategory } from "@/lib/kk/api";

const CATS: MemoryCategory[] = ["日常", "約會", "計劃", "其他"];

function Form() {
  const router = useRouter();
  const sp = useSearchParams();
  const prefillOriginal = sp.get("original") ?? "";
  const prefillTitle = sp.get("title") ?? "";
  const fromMerge = sp.get("merge") === "1";

  const [title, setTitle] = useState(
    prefillTitle || (prefillOriginal ? prefillOriginal.slice(0, 24) : ""),
  );
  const [original, setOriginal] = useState(prefillOriginal);
  const [category, setCategory] = useState<MemoryCategory>("日常");
  const [note, setNote] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const hint = useMemo(
    () =>
      fromMerge
        ? "由聊天多選合併 · 唔扣 AI 配額"
        : "手動新增記憶",
    [fromMerge],
  );

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim() || !original.trim()) return;
    setBusy(true);
    setError(null);
    try {
      if (fromMerge) {
        await kk_memory_from_chat({
          title: title.trim(),
          originalWords: original.trim(),
          category,
          note: note.trim() || undefined,
        });
      } else {
        await kk_memory_create({
          title: title.trim(),
          originalWords: original.trim(),
          category,
          note: note.trim() || undefined,
        });
      }
      router.push("/memory");
    } catch (err) {
      setError(err instanceof Error ? err.message : "failed");
      setBusy(false);
    }
  };

  return (
    <main className="mx-auto min-h-screen max-w-2xl p-4 pb-24">
      <div className="mb-4 flex items-center justify-between">
        <Link href="/memory" className="text-sm text-rose">
          ← 返回
        </Link>
        <h1 className="text-lg">新增記憶</h1>
        <span />
      </div>
      <p className="mb-4 text-xs text-ink-soft">{hint}</p>
      <form onSubmit={submit} className="space-y-4 rounded-3xl bg-surface p-5 shadow-sm">
        <label className="block text-sm">
          標題
          <input
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            className="mt-1 w-full rounded-2xl border border-line bg-cream px-4 py-3 outline-none focus:border-rose"
            required
          />
        </label>
        <label className="block text-sm">
          原話
          <textarea
            value={original}
            onChange={(e) => setOriginal(e.target.value)}
            rows={4}
            className="mt-1 w-full rounded-2xl border border-line bg-cream px-4 py-3 outline-none focus:border-rose"
            required
          />
        </label>
        <div>
          <p className="mb-2 text-sm">分類</p>
          <div className="flex flex-wrap gap-2">
            {CATS.map((c) => (
              <button
                key={c}
                type="button"
                onClick={() => setCategory(c)}
                className={`rounded-full px-3 py-1 text-xs ${
                  category === c ? "bg-rose text-white" : "bg-cream-deep"
                }`}
              >
                {c}
              </button>
            ))}
          </div>
        </div>
        <label className="block text-sm">
          筆記／計劃摘要（可選）
          <textarea
            value={note}
            onChange={(e) => setNote(e.target.value)}
            rows={3}
            className="mt-1 w-full rounded-2xl border border-line bg-cream px-4 py-3 outline-none focus:border-rose"
          />
        </label>
        {error && <p className="text-sm text-rose">{error}</p>}
        <button
          type="submit"
          disabled={busy}
          className="w-full rounded-2xl bg-rose py-3 font-medium text-white disabled:opacity-60"
        >
          {busy ? "儲存緊…" : "儲存"}
        </button>
      </form>
    </main>
  );
}

export default function MemoryNewPage() {
  return (
    <Suspense fallback={<main className="p-8 text-center text-ink-soft">載入…</main>}>
      <Form />
    </Suspense>
  );
}
