"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import dayjs from "dayjs";
import { createClient } from "@/lib/supabase/client";
import { errMsg } from "@/lib/errors";
import { loadKeyPair, publicKeyFromBase64 } from "@/lib/crypto/keys";
import { deriveChatKey } from "@/lib/crypto/derive";
import {
  fetchEntries,
  addEntry,
  deleteEntry,
  subscribeEntries,
  type DecryptedEntry,
  type EntryPayload,
  type EntryTag,
} from "@/lib/services/memory";

type Ready = { coupleId: string; myId: string; chatKey: Uint8Array };

const TAGS: EntryTag[] = [
  "date", "anniversary", "trip", "meal", "movie",
  "show", "shopping", "home", "work", "other",
];

const TAG_LABEL: Record<EntryTag, string> = {
  date: "拍拖", anniversary: "紀念", trip: "旅行", meal: "食飯", movie: "電影",
  show: "演出", shopping: "shopping", home: "屋企", work: "工作", other: "其他",
};

export default function MemoryPage() {
  const router = useRouter();
  const supabaseRef = useRef(createClient());
  const [ready, setReady] = useState<Ready | null>(null);
  const [entries, setEntries] = useState<DecryptedEntry[]>([]);
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
      const chatKey = deriveChatKey(kp.privateKey, publicKeyFromBase64(partner.public_key), couple.id);
      if (cancelled) return;
      setReady({ coupleId: couple.id, myId: user.id, chatKey });

      // Entries are newest-first; merge by id-dedupe so the snapshot and any
      // events arriving during the handshake coexist without duplicates.
      const mergeEntries = (incoming: DecryptedEntry[]) =>
        setEntries((prev) => {
          const seen = new Set(prev.map((x) => x.id));
          const fresh = incoming.filter((x) => !seen.has(x.id));
          if (fresh.length === 0) return prev;
          const merged = [...prev, ...fresh];
          merged.sort((a, b) => b.createdAt.localeCompare(a.createdAt));
          return merged;
        });

      // Subscribe first, fetch on SUBSCRIBED — no-gap pattern (matches chat/us).
      const channel = subscribeEntries(
        supabase,
        couple.id,
        chatKey,
        (e) => mergeEntries([e]),
        (id) => setEntries((prev) => prev.filter((x) => x.id !== id)),
        () => {
          void (async () => {
            try {
              const initial = await fetchEntries(supabase, couple.id, chatKey);
              if (!cancelled) mergeEntries(initial);
            } catch (err) {
              if (!cancelled) setError(errMsg(err));
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
        <h1 className="text-lg text-ink">紀念冊</h1>
        <button
          onClick={() => setShowAdd(true)}
          disabled={!ready}
          className="rounded-full bg-rose px-4 py-1.5 text-sm font-medium text-white transition active:scale-95 disabled:opacity-60"
        >
          ＋ 新事件
        </button>
      </header>

      {error && (
        <div className="bg-rose-soft px-4 py-2 text-sm text-rose">{error}</div>
      )}

      <div className="mx-auto w-full max-w-2xl flex-1 px-4 py-6">
        {entries.length === 0 && ready && (
          <p className="kao mt-20 text-center text-ink-soft">
            (◍•ᴗ•◍) 仲未有回憶
          </p>
        )}
        <ul className="grid gap-3 sm:grid-cols-2">
          {entries.map((e) => (
            <li
              key={e.id}
              className="rounded-2xl bg-surface p-4 shadow-sm transition hover:shadow-md"
            >
              <div className="flex items-start justify-between">
                <div>
                  <p className="text-xs text-ink-soft">
                    {e.payload?.dateISO} {e.payload?.time}
                  </p>
                  <h3 className="mt-1 text-base font-medium text-ink">
                    {e.payload?.title ?? "(decryption failed)"}
                  </h3>
                  {e.payload?.location && (
                    <p className="mt-0.5 text-xs text-ink-soft">📍 {e.payload.location}</p>
                  )}
                </div>
                <span className="rounded-full bg-rose-soft px-2 py-0.5 text-[10px] text-rose">
                  {e.payload ? TAG_LABEL[e.payload.tag] : "?"}
                </span>
              </div>
              {e.payload?.notes && (
                <p className="mt-2 line-clamp-3 text-sm text-ink-soft">{e.payload.notes}</p>
              )}
              <button
                onClick={async () => {
                  if (!confirm("刪除呢個事件？")) return;
                  try {
                    await deleteEntry(supabaseRef.current, e.id);
                  } catch (err) {
                    setError(errMsg(err));
                  }
                }}
                className="mt-2 text-[10px] text-ink-soft underline"
              >
                刪除
              </button>
            </li>
          ))}
        </ul>
      </div>

      {showAdd && ready && (
        <AddDialog
          myId={ready.myId}
          onClose={() => setShowAdd(false)}
          onSubmit={async (payload) => {
            try {
              await addEntry(
                supabaseRef.current,
                ready.coupleId,
                ready.myId,
                ready.chatKey,
                payload,
              );
              setShowAdd(false);
            } catch (err) {
              setError(errMsg(err));
            }
          }}
        />
      )}
    </main>
  );
}

const AddDialog = ({
  myId,
  onClose,
  onSubmit,
}: {
  myId: string;
  onClose: () => void;
  onSubmit: (p: Omit<EntryPayload, "v">) => Promise<void>;
}) => {
  const [title, setTitle] = useState("");
  const [dateISO, setDateISO] = useState(dayjs().format("YYYY-MM-DD"));
  const [time, setTime] = useState("");
  const [location, setLocation] = useState("");
  const [tag, setTag] = useState<EntryTag>("date");
  const [notes, setNotes] = useState("");
  const [busy, setBusy] = useState(false);

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/40 sm:items-center">
      <form
        onSubmit={async (e) => {
          e.preventDefault();
          if (!title || busy) return;
          setBusy(true);
          await onSubmit({
            title,
            dateISO,
            time: time || undefined,
            location: location || undefined,
            proposedBy: myId,
            who: "both",
            tag,
            isSpecial: false,
            notes: notes || undefined,
          });
          setBusy(false);
        }}
        className="float-in max-h-[90vh] w-full max-w-md overflow-y-auto rounded-t-3xl bg-surface p-6 shadow-2xl sm:rounded-3xl"
      >
        <h2 className="text-xl text-ink">新事件</h2>
        <Field label="標題" value={title} onChange={setTitle} required />
        <Field label="日期" value={dateISO} onChange={setDateISO} type="date" required />
        <Field label="時間" value={time} onChange={setTime} type="time" />
        <Field label="地點" value={location} onChange={setLocation} placeholder="例如：尖沙咀" />
        <label className="mt-4 block">
          <span className="mb-1 block text-sm font-medium text-ink-soft">分類</span>
          <select
            value={tag}
            onChange={(e) => setTag(e.target.value as EntryTag)}
            className="w-full rounded-2xl border border-line bg-cream px-4 py-3 outline-none focus:border-rose"
          >
            {TAGS.map((t) => (
              <option key={t} value={t}>{TAG_LABEL[t]}</option>
            ))}
          </select>
        </label>
        <label className="mt-4 block">
          <span className="mb-1 block text-sm font-medium text-ink-soft">備註</span>
          <textarea
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            rows={3}
            className="w-full rounded-2xl border border-line bg-cream px-4 py-3 outline-none focus:border-rose"
          />
        </label>
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
