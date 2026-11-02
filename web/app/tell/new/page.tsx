"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { kk_want_create } from "@/lib/kk/api";

export default function TellNewPage() {
  const router = useRouter();
  const [title, setTitle] = useState("");
  const [content, setContent] = useState("");
  const [deadline, setDeadline] = useState("");
  const [reminder, setReminder] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!content.trim()) return;
    setBusy(true);
    setError(null);
    try {
      await kk_want_create({
        title: title.trim() || undefined,
        content: content.trim(),
        deadline: deadline || undefined,
        reminder,
      });
      router.push("/tell");
    } catch (err) {
      setError(err instanceof Error ? err.message : "failed");
      setBusy(false);
    }
  };

  return (
    <main className="mx-auto min-h-screen max-w-2xl p-4 pb-24">
      <div className="mb-4 flex items-center justify-between">
        <Link href="/tell" className="text-sm text-rose">
          ← 返回
        </Link>
        <h1 className="text-lg">想你知道</h1>
        <span />
      </div>
      <form onSubmit={submit} className="space-y-4 rounded-3xl bg-surface p-5 shadow-sm">
        <label className="block text-sm">
          標題（可選）
          <input
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            className="mt-1 w-full rounded-2xl border border-line bg-cream px-4 py-3 outline-none focus:border-rose"
          />
        </label>
        <label className="block text-sm">
          內容
          <textarea
            value={content}
            onChange={(e) => setContent(e.target.value)}
            rows={4}
            required
            className="mt-1 w-full rounded-2xl border border-line bg-cream px-4 py-3 outline-none focus:border-rose"
          />
        </label>
        <label className="block text-sm">
          限期（可選）
          <input
            type="date"
            value={deadline}
            onChange={(e) => setDeadline(e.target.value)}
            className="mt-1 w-full rounded-2xl border border-line bg-cream px-4 py-3 outline-none focus:border-rose"
          />
        </label>
        <label className="flex items-center justify-between text-sm">
          <span>到期提醒（後端 09:00 HKT push）</span>
          <input
            type="checkbox"
            checked={reminder}
            onChange={(e) => setReminder(e.target.checked)}
          />
        </label>
        {error && <p className="text-sm text-rose">{error}</p>}
        <button
          type="submit"
          disabled={busy || !content.trim()}
          className="w-full rounded-2xl bg-rose py-3 font-medium text-white disabled:opacity-60"
        >
          {busy ? "儲存緊…" : "儲存"}
        </button>
      </form>
    </main>
  );
}
