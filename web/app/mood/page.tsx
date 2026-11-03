"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import {
  MOODS,
  getMoodForToday,
  refreshMoodFromServer,
  setMoodForToday,
  type MoodId,
} from "@/lib/kk/api";

export default function MoodPage() {
  const router = useRouter();
  const [picked, setPicked] = useState<MoodId | null>(null);
  const [cheerSkip, setCheerSkip] = useState(false);
  const [doneMood, setDoneMood] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    void (async () => {
      const cached = getMoodForToday();
      if (cached) {
        router.replace("/chat");
        return;
      }
      const remote = await refreshMoodFromServer();
      if (remote) router.replace("/chat");
    })();
  }, [router]);

  const continueToApp = async () => {
    if (!picked || busy) return;
    setBusy(true);
    setError(null);
    try {
      await setMoodForToday(picked);
      router.replace("/chat");
    } catch (e) {
      setError(e instanceof Error ? e.message : "設定心情失敗");
      setBusy(false);
    }
  };

  if (doneMood && !cheerSkip) {
    return (
      <main className="flex min-h-screen items-center justify-center p-6">
        <div className="w-full max-w-md rounded-3xl bg-surface p-8 text-center shadow-xl">
          <p className="kao text-3xl">(づ｡◕‿‿◕｡)づ</p>
          <h1 className="mt-3 text-xl">加把勁呀</h1>
          <p className="mt-2 text-sm text-ink-soft">輕量打氣 · 可以略過</p>
          <button
            type="button"
            onClick={() => void continueToApp()}
            disabled={busy}
            className="mt-6 w-full rounded-2xl bg-rose py-3 font-medium text-white disabled:opacity-50"
          >
            {busy ? "儲存緊…" : "入去 · Continue"}
          </button>
          <button
            type="button"
            disabled={busy}
            onClick={() => {
              setCheerSkip(true);
              void continueToApp();
            }}
            className="mt-3 w-full text-sm text-ink-soft disabled:opacity-50"
          >
            略過打氣
          </button>
          {error && <p className="mt-3 text-sm text-rose">{error}</p>}
        </div>
      </main>
    );
  }

  return (
    <main className="flex min-h-screen items-center justify-center p-6">
      <div className="w-full max-w-md rounded-3xl bg-surface p-6 shadow-xl">
        <h1 className="text-center text-xl">今日心情？</h1>
        <p className="mt-1 text-center text-xs text-ink-soft">
          How are you today? · 每日 06:00 HKT 起須選一次，唔可以 skip
        </p>
        <div className="mt-6 grid grid-cols-2 gap-3">
          {MOODS.map((m) => (
            <button
              key={m.id}
              type="button"
              onClick={() => setPicked(m.id)}
              className={`rounded-2xl border px-3 py-4 text-center transition ${
                picked === m.id ? "border-rose bg-rose-soft" : "border-line bg-cream"
              }`}
            >
              <div className="kao text-sm">{m.kao}</div>
              <div className="mt-1 text-sm font-medium">{m.id}</div>
              <div className="text-[10px] text-ink-soft">{m.en}</div>
            </button>
          ))}
        </div>
        <button
          type="button"
          disabled={!picked}
          onClick={() => setDoneMood(true)}
          className="mt-6 w-full rounded-2xl bg-rose py-3 font-medium text-white disabled:opacity-40"
        >
          繼續 · Continue
        </button>
      </div>
    </main>
  );
}
