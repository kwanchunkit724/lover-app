"use client";

// "Us" tab — date-card deck + history. The 4th main tab in iOS is named
// "我哋" (us); web reuses /us as the route.

import { useEffect, useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import dayjs from "dayjs";
import { createClient } from "@/lib/supabase/client";
import { errMsg } from "@/lib/errors";
import { loadKeyPair, publicKeyFromBase64 } from "@/lib/crypto/keys";
import { deriveChatKey } from "@/lib/crypto/derive";
import {
  DATE_CARDS,
  fetchHistory,
  markCardDone,
  subscribeHistory,
  type DateCard,
  type DecryptedHistory,
} from "@/lib/services/activities";

type Ready = { coupleId: string; myId: string; chatKey: Uint8Array };

export default function UsPage() {
  const router = useRouter();
  const supabaseRef = useRef(createClient());
  const [ready, setReady] = useState<Ready | null>(null);
  const [history, setHistory] = useState<DecryptedHistory[]>([]);
  const [activeCard, setActiveCard] = useState<DateCard | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const supabase = supabaseRef.current;
    let cancelled = false;
    let unsub: (() => void) | undefined;

    (async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        router.push("/login");
        return;
      }
      const { data: couple, error: coupleErr } = await supabase
        .from("couples")
        .select("id, user_a_id, user_b_id")
        .or(`user_a_id.eq.${user.id},user_b_id.eq.${user.id}`)
        .maybeSingle();
      if (coupleErr) {
        if (!cancelled) setError(errMsg(coupleErr));
        return;
      }
      if (!couple) {
        router.push("/pair");
        return;
      }
      const partnerId =
        couple.user_a_id === user.id ? couple.user_b_id : couple.user_a_id;
      const { data: partner, error: partnerErr } = await supabase
        .from("users")
        .select("public_key")
        .eq("id", partnerId)
        .maybeSingle();
      if (partnerErr) {
        if (!cancelled) setError(errMsg(partnerErr));
        return;
      }
      if (!partner?.public_key) {
        setError("伴侶仲未 set 好個 key。");
        return;
      }
      const kp = loadKeyPair();
      if (!kp) {
        setError("本機冇 key — 請完成 onboarding。");
        return;
      }
      const chatKey = deriveChatKey(kp.privateKey, publicKeyFromBase64(partner.public_key), couple.id);
      if (cancelled) return;
      setReady({ coupleId: couple.id, myId: user.id, chatKey });

      const mergeHistory = (incoming: DecryptedHistory[]) =>
        setHistory((prev) => {
          const seen = new Set(prev.map((h) => h.id));
          const fresh = incoming.filter((h) => !seen.has(h.id));
          if (fresh.length === 0) return prev;
          const merged = [...fresh, ...prev];
          merged.sort((a, b) => b.createdAt.localeCompare(a.createdAt));
          return merged;
        });

      // Subscribe first, fetch on SUBSCRIBED — same no-gap pattern as chat.
      const channel = subscribeHistory(
        supabase,
        couple.id,
        chatKey,
        (h) => mergeHistory([h]),
        () => {
          void (async () => {
            try {
              const initial = await fetchHistory(supabase, couple.id, chatKey);
              if (!cancelled) mergeHistory(initial);
            } catch (e) {
              if (!cancelled) setError(errMsg(e));
            }
          })();
        },
      );
      unsub = () => void supabase.removeChannel(channel);
    })();

    return () => {
      cancelled = true;
      unsub?.();
    };
  }, [router]);

  const doneIds = useMemo(
    () => new Set(history.map((h) => h.payload?.cardId).filter((x): x is number => x != null)),
    [history],
  );

  const draw = () => {
    const undone = DATE_CARDS.filter((c) => !doneIds.has(c.id));
    const pool = undone.length > 0 ? undone : DATE_CARDS;
    setActiveCard(pool[Math.floor(Math.random() * pool.length)]);
  };

  return (
    <main className="flex min-h-screen flex-col">
      <header className="flex items-center justify-between border-b border-line bg-surface/80 px-4 py-3 backdrop-blur">
        <h1 className="text-lg text-ink">我哋</h1>
        <span className="kao text-xs text-ink-soft">
          {doneIds.size} / {DATE_CARDS.length}
        </span>
      </header>

      {error && (
        <div className="bg-rose-soft px-4 py-2 text-sm text-rose">{error}</div>
      )}

      <div className="mx-auto w-full max-w-2xl flex-1 px-4 py-6">
        <button
          onClick={draw}
          disabled={!ready}
          className="w-full rounded-3xl bg-rose px-5 py-6 text-lg font-medium text-white shadow-lg transition active:scale-95 disabled:opacity-60"
        >
          🎲 抽張卡
        </button>

        {history.length > 0 && (
          <section className="mt-8">
            <h2 className="text-sm font-medium text-ink-soft">玩過嘅</h2>
            <ul className="mt-3 grid gap-2">
              {history.map((h) => {
                const card = DATE_CARDS.find((c) => c.id === h.payload?.cardId);
                return (
                  <li
                    key={h.id}
                    className="flex items-center justify-between gap-3 rounded-2xl bg-surface px-4 py-3 shadow-sm"
                  >
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-base text-ink">
                        {card?.title ?? `Card #${h.payload?.cardId}`}
                      </p>
                      {h.payload?.reflection && (
                        <p className="mt-0.5 truncate text-xs text-ink-soft italic">
                          “{h.payload.reflection}”
                        </p>
                      )}
                    </div>
                    <span className="kao shrink-0 text-xs text-ink-soft">
                      {dayjs(h.createdAt).format("M/D")}
                    </span>
                  </li>
                );
              })}
            </ul>
          </section>
        )}
      </div>

      {activeCard && ready && (
        <CardDialog
          card={activeCard}
          onClose={() => setActiveCard(null)}
          onDone={async (reflection) => {
            try {
              await markCardDone(
                supabaseRef.current,
                ready.coupleId,
                ready.myId,
                ready.chatKey,
                activeCard.id,
                reflection,
              );
              // No manual refetch — the realtime INSERT echo delivers the new
              // row to mergeHistory (deduped), same model as chat's send().
              setActiveCard(null);
            } catch (e) {
              setError(errMsg(e));
            }
          }}
        />
      )}
    </main>
  );
}

const CardDialog = ({
  card,
  onClose,
  onDone,
}: {
  card: DateCard;
  onClose: () => void;
  onDone: (reflection?: string) => Promise<void>;
}) => {
  const [reflection, setReflection] = useState("");
  const [busy, setBusy] = useState(false);

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/50 sm:items-center">
      <div className="float-in w-full max-w-md rounded-t-3xl bg-cream p-6 shadow-2xl sm:rounded-3xl">
        <p className="kao text-center text-2xl">{card.kaomoji}</p>
        <h2 className="mt-2 text-center text-2xl text-ink">{card.title}</h2>
        <p className="mt-1 text-center text-sm text-ink-soft">{card.mood} · {card.cost}</p>
        <p className="mt-4 rounded-2xl bg-surface px-4 py-3 text-center text-ink">
          {card.detail}
        </p>
        <textarea
          value={reflection}
          onChange={(e) => setReflection(e.target.value)}
          placeholder="完咗想寫返兩句？(optional)"
          rows={2}
          className="mt-4 w-full rounded-2xl border border-line bg-surface px-4 py-3 outline-none focus:border-rose"
        />
        <div className="mt-4 flex gap-2">
          <button
            type="button"
            onClick={onClose}
            className="flex-1 rounded-2xl border border-line bg-surface px-4 py-3 text-ink"
          >
            再抽
          </button>
          <button
            type="button"
            disabled={busy}
            onClick={async () => {
              setBusy(true);
              await onDone(reflection || undefined);
              setBusy(false);
            }}
            className="flex-1 rounded-2xl bg-rose px-4 py-3 font-medium text-white active:scale-95 disabled:opacity-60"
          >
            {busy ? "記錄緊…" : "完成 ✓"}
          </button>
        </div>
      </div>
    </div>
  );
};
