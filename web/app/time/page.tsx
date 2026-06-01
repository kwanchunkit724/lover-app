"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import dayjs from "dayjs";
import { createClient } from "@/lib/supabase/client";
import { errMsg } from "@/lib/errors";
import { loadKeyPair, publicKeyFromBase64 } from "@/lib/crypto/keys";
import { deriveChatKey } from "@/lib/crypto/derive";
import {
  fetchAnniversaries,
  addAnniversary,
  deleteAnniversary,
  subscribeAnniversaries,
  type DecryptedAnniversary,
  type AnniversaryPayload,
} from "@/lib/services/time";

type Ready = { coupleId: string; myId: string; chatKey: Uint8Array };

export default function TimePage() {
  const router = useRouter();
  const supabaseRef = useRef(createClient());
  const [ready, setReady] = useState<Ready | null>(null);
  const [items, setItems] = useState<DecryptedAnniversary[]>([]);
  const [showAdd, setShowAdd] = useState(false);
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
      const partnerPub = publicKeyFromBase64(partner.public_key);
      const chatKey = deriveChatKey(kp.privateKey, partnerPub, couple.id);
      if (cancelled) return;
      setReady({ coupleId: couple.id, myId: user.id, chatKey });

      const sortByNext = (xs: DecryptedAnniversary[]) =>
        [...xs].sort((a, b) => (a.daysUntilNext ?? 99999) - (b.daysUntilNext ?? 99999));
      const mergeItems = (incoming: DecryptedAnniversary[]) =>
        setItems((prev) => {
          const seen = new Set(prev.map((x) => x.id));
          const fresh = incoming.filter((x) => !seen.has(x.id));
          if (fresh.length === 0) return prev;
          return sortByNext([...prev, ...fresh]);
        });

      // Subscribe first, fetch on SUBSCRIBED — no-gap pattern (matches chat/us).
      const channel = subscribeAnniversaries(
        supabase,
        couple.id,
        chatKey,
        (a) => mergeItems([a]),
        (id) => setItems((prev) => prev.filter((x) => x.id !== id)),
        () => {
          void (async () => {
            try {
              const initial = await fetchAnniversaries(supabase, couple.id, chatKey);
              if (!cancelled) mergeItems(initial);
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

  return (
    <main className="flex min-h-screen flex-col">
      <header className="flex items-center justify-between border-b border-line bg-surface/80 px-4 py-3 backdrop-blur">
        <h1 className="text-lg text-ink">紀念日</h1>
        <button
          onClick={() => setShowAdd(true)}
          disabled={!ready}
          className="rounded-full bg-rose px-4 py-1.5 text-sm font-medium text-white transition active:scale-95 disabled:opacity-60"
        >
          ＋ 新增
        </button>
      </header>

      {error && (
        <div className="bg-rose-soft px-4 py-2 text-sm text-rose">{error}</div>
      )}

      <div className="mx-auto w-full max-w-2xl flex-1 px-4 py-6">
        {items.length === 0 && ready && (
          <p className="kao mt-20 text-center text-ink-soft">
            (｡•ᴗ-)_ 仲未有紀念日
          </p>
        )}
        <ul className="flex flex-col gap-3">
          {items.map((a) => (
            <li
              key={a.id}
              className="flex items-center justify-between rounded-2xl bg-surface px-4 py-3 shadow-sm"
            >
              <div>
                <p className="text-base text-ink">
                  {a.payload?.emoji ?? "💖"} {a.payload?.title ?? "(decryption failed)"}
                </p>
                {a.payload?.subtitle && (
                  <p className="text-xs text-ink-soft">{a.payload.subtitle}</p>
                )}
                <p className="kao mt-1 text-xs">
                  {a.payload?.baseDateISO} · {a.payload?.recur === "yearly" ? "每年" : "每月"}
                </p>
              </div>
              <div className="flex flex-col items-end gap-1">
                <span className="text-2xl font-semibold text-rose">
                  {a.daysUntilNext !== null ? a.daysUntilNext : "—"}
                </span>
                <span className="text-[10px] text-ink-soft">日後</span>
                <button
                  onClick={async () => {
                    try {
                      await deleteAnniversary(supabaseRef.current, a.id);
                    } catch (e) {
                      setError(errMsg(e));
                    }
                  }}
                  className="mt-1 text-[10px] text-ink-soft underline"
                >
                  刪除
                </button>
              </div>
            </li>
          ))}
        </ul>
      </div>

      {showAdd && ready && (
        <AddDialog
          onClose={() => setShowAdd(false)}
          onSubmit={async (payload) => {
            try {
              await addAnniversary(
                supabaseRef.current,
                ready.coupleId,
                ready.myId,
                ready.chatKey,
                payload,
              );
              setShowAdd(false);
            } catch (e) {
              setError(errMsg(e));
            }
          }}
        />
      )}
    </main>
  );
}

const AddDialog = ({
  onClose,
  onSubmit,
}: {
  onClose: () => void;
  onSubmit: (p: Omit<AnniversaryPayload, "v">) => Promise<void>;
}) => {
  const [title, setTitle] = useState("");
  const [baseDateISO, setBaseDateISO] = useState(dayjs().format("YYYY-MM-DD"));
  const [recur, setRecur] = useState<"yearly" | "monthly">("yearly");
  const [emoji, setEmoji] = useState("💖");
  const [busy, setBusy] = useState(false);

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/40 sm:items-center">
      <form
        onSubmit={async (e) => {
          e.preventDefault();
          if (!title || busy) return;
          setBusy(true);
          await onSubmit({ title, baseDateISO, recur, emoji });
          setBusy(false);
        }}
        className="float-in w-full max-w-md rounded-t-3xl bg-surface p-6 shadow-2xl sm:rounded-3xl"
      >
        <h2 className="text-xl text-ink">新紀念日</h2>
        <Field label="標題" value={title} onChange={setTitle} required />
        <Field label="日期" value={baseDateISO} onChange={setBaseDateISO} type="date" required />
        <label className="mt-4 block">
          <span className="mb-1 block text-sm font-medium text-ink-soft">重複</span>
          <select
            value={recur}
            onChange={(e) => setRecur(e.target.value as "yearly" | "monthly")}
            className="w-full rounded-2xl border border-line bg-cream px-4 py-3 outline-none focus:border-rose"
          >
            <option value="yearly">每年</option>
            <option value="monthly">每月</option>
          </select>
        </label>
        <Field label="Emoji" value={emoji} onChange={setEmoji} placeholder="💖" />
        <div className="mt-6 flex gap-2">
          <button
            type="button"
            onClick={onClose}
            className="flex-1 rounded-2xl border border-line bg-cream px-4 py-3 text-ink"
          >
            取消
          </button>
          <button
            type="submit"
            disabled={!title || busy}
            className="flex-1 rounded-2xl bg-rose px-4 py-3 font-medium text-white active:scale-95 disabled:opacity-60"
          >
            {busy ? "加入緊…" : "加入"}
          </button>
        </div>
      </form>
    </div>
  );
};

const Field = ({
  label,
  value,
  onChange,
  type = "text",
  placeholder,
  required,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  type?: string;
  placeholder?: string;
  required?: boolean;
}) => (
  <label className="mt-4 block">
    <span className="mb-1 block text-sm font-medium text-ink-soft">{label}</span>
    <input
      type={type}
      value={value}
      onChange={(e) => onChange(e.target.value)}
      placeholder={placeholder}
      required={required}
      className="w-full rounded-2xl border border-line bg-cream px-4 py-3 outline-none focus:border-rose"
    />
  </label>
);
