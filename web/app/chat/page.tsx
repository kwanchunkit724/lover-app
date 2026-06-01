"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import dayjs from "dayjs";
import { createClient } from "@/lib/supabase/client";
import { errMsg } from "@/lib/errors";
import { loadKeyPair, publicKeyFromBase64 } from "@/lib/crypto/keys";
import { deriveChatKey } from "@/lib/crypto/derive";
import {
  fetchInitial,
  sendText,
  sendPhoto,
  subscribe,
  type DecryptedMessage,
} from "@/lib/services/chat";
import { downloadAndDecrypt, bytesToBlobUrl, sniffMime } from "@/lib/services/media";
import type { SupabaseClient } from "@supabase/supabase-js";

type Ready = {
  coupleId: string;
  partnerId: string;
  partnerName: string;
  myId: string;
  chatKey: Uint8Array;
};

const MAX_PHOTO_BYTES = 8 * 1024 * 1024; // 8 MB sanity cap
// Safety-net resync cadence: catches realtime events Supabase dropped under
// load. Short enough that a missed message self-heals quickly; merge is
// id-deduped so repeated fetches are idempotent.
const RESYNC_MS = 10_000;

export default function ChatPage() {
  const router = useRouter();
  const [ready, setReady] = useState<Ready | null>(null);
  const [messages, setMessages] = useState<DecryptedMessage[]>([]);
  const [draft, setDraft] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [sending, setSending] = useState(false);
  // Stable client via useState initializer (not useRef) so it can be read
  // during render — e.g. passed to <Bubble> — without tripping the
  // no-ref-access-during-render lint, while still being created exactly once.
  const [supabase] = useState(() => createClient());
  const scrollerRef = useRef<HTMLDivElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Bootstrap: pull session, couple, partner key; derive chat key.
  useEffect(() => {
    let cancelled = false;
    let unsub: (() => void) | undefined;
    let pollId: ReturnType<typeof setInterval> | undefined;

    // Wire the realtime channel once we have a chatKey. Stored in `unsub`
    // (NOT returned from the async IIFE — React discards that) so the effect
    // cleanup actually tears the channel down on unmount.
    const startChannel = (
      coupleId: string,
      myId: string,
      partnerId: string,
      partnerName: string,
      chatKey: Uint8Array,
    ) => {
      setReady({ coupleId, partnerId, partnerName, myId, chatKey });

      const mergeMessages = (incoming: DecryptedMessage[]) =>
        setMessages((prev) => {
          const seen = new Set(prev.map((m) => m.id));
          const fresh = incoming.filter((m) => !seen.has(m.id));
          if (fresh.length === 0) return prev;
          const merged = [...prev, ...fresh];
          merged.sort((a, b) => a.createdAt.localeCompare(b.createdAt));
          return merged;
        });

      const resync = async () => {
        try {
          const rows = await fetchInitial(supabase, coupleId, chatKey);
          if (!cancelled) mergeMessages(rows);
        } catch (e) {
          if (!cancelled) setError(errMsg(e));
        }
      };

      // Subscribe FIRST, then fetch once the channel is live — closes the
      // race where an INSERT lands during the handshake. onSubscribed also
      // re-fires on reconnect, resyncing anything missed.
      const channel = subscribe(
        supabase,
        coupleId,
        chatKey,
        (msg) => mergeMessages([msg]),
        () => void resync(),
      );
      // Safety net: Supabase Realtime can drop a postgres_changes event under
      // load / flaky connections, which would silently lose an incoming
      // message until reload. A light periodic resync (merge is id-deduped, so
      // it's cheap and idempotent) self-heals any dropped event within one
      // interval. Also resync when the tab regains focus.
      const resyncId = setInterval(() => void resync(), RESYNC_MS);
      const onVisible = () => {
        if (document.visibilityState === "visible") void resync();
      };
      document.addEventListener("visibilitychange", onVisible);
      unsub = () => {
        void supabase.removeChannel(channel);
        clearInterval(resyncId);
        document.removeEventListener("visibilitychange", onVisible);
      };
    };

    (async () => {
      try {
        const {
          data: { user },
        } = await supabase.auth.getUser();
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

        const kp = loadKeyPair();
        if (!kp) {
          setError("本機冇 key — 請重新登入並完成 onboarding。");
          return;
        }

        // Resolve the partner's public key. If they paired but haven't logged
        // in to upload a key yet, poll until it appears instead of dead-ending.
        const tryDerive = async (): Promise<boolean> => {
          const { data: partner, error: partnerErr } = await supabase
            .from("users")
            .select("my_name, public_key")
            .eq("id", partnerId)
            .maybeSingle();
          if (partnerErr) {
            if (!cancelled) setError(errMsg(partnerErr));
            return false;
          }
          if (!partner?.public_key) return false;
          if (cancelled) return true;
          const chatKey = deriveChatKey(
            kp.privateKey,
            publicKeyFromBase64(partner.public_key),
            couple.id,
          );
          setError(null);
          startChannel(
            couple.id,
            user.id,
            partnerId,
            partner.my_name as string,
            chatKey,
          );
          return true;
        };

        const ok = await tryDerive();
        if (!ok && !cancelled) {
          setError("等緊伴侶登入一次先可以開始傾偈（會自動繼續）…");
          pollId = setInterval(() => {
            void (async () => {
              if (cancelled) return;
              const done = await tryDerive();
              if (done && pollId) {
                clearInterval(pollId);
                pollId = undefined;
              }
            })();
          }, 3000);
        }
      } catch (e) {
        if (!cancelled) setError(errMsg(e));
      }
    })();

    return () => {
      cancelled = true;
      unsub?.();
      if (pollId) clearInterval(pollId);
    };
  }, [router, supabase]);

  // Auto-scroll to bottom on new messages.
  useEffect(() => {
    scrollerRef.current?.scrollTo({
      top: scrollerRef.current.scrollHeight,
      behavior: "smooth",
    });
  }, [messages.length]);

  const send = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!ready || !draft.trim() || sending) return;
    setSending(true);
    setError(null);
    try {
      await sendText(
        supabase,
        ready.coupleId,
        ready.myId,
        ready.chatKey,
        draft.trim(),
      );
      setDraft("");
    } catch (e) {
      setError(errMsg(e));
    } finally {
      setSending(false);
    }
  };

  const onPickPhoto = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    e.target.value = ""; // reset so picking the same file twice re-fires
    if (!file || !ready || sending) return;
    if (file.size > MAX_PHOTO_BYTES) {
      setError(`相片太大 (${Math.round(file.size / 1024 / 1024)} MB) — 上限 8 MB`);
      return;
    }
    setSending(true);
    setError(null);
    try {
      const bytes = new Uint8Array(await file.arrayBuffer());
      await sendPhoto(
        supabase,
        ready.coupleId,
        ready.myId,
        ready.chatKey,
        bytes,
      );
    } catch (e) {
      setError(errMsg(e));
    } finally {
      setSending(false);
    }
  };

  return (
    <main className="flex h-screen flex-col">
      <header className="flex items-center justify-between border-b border-line bg-surface/80 px-4 py-3 backdrop-blur">
        <h1 className="text-lg text-ink">
          {ready ? `同 ${ready.partnerName} 嘅對話` : "載入緊…"}
        </h1>
        <span className="kao text-xs">E2EE 🔒</span>
      </header>

      {error && (
        <button
          onClick={() => setError(null)}
          aria-label="關閉錯誤提示"
          className="flex w-full items-center justify-between gap-2 bg-rose-soft px-4 py-2 text-left text-sm text-rose focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-rose/40"
        >
          <span>{error}</span>
          <span aria-hidden className="shrink-0">✕</span>
        </button>
      )}

      <div
        ref={scrollerRef}
        className="flex-1 overflow-y-auto px-4 py-6"
      >
        <div className="mx-auto flex min-h-full max-w-2xl flex-col justify-end gap-2">
          {messages.map((m) => (
            <Bubble
              key={m.id}
              msg={m}
              mine={ready?.myId === m.senderId}
              supabase={supabase}
              chatKey={ready?.chatKey ?? null}
            />
          ))}
          {messages.length === 0 && ready && (
            <p className="kao my-auto text-center text-ink-soft">
              (｡•ᴗ-)_ 仲未有信息，sayhi啦！
            </p>
          )}
        </div>
      </div>

      <form
        onSubmit={send}
        className="border-t border-line bg-surface px-3 py-3"
      >
        <div className="mx-auto flex max-w-2xl items-center gap-2">
          <input
            ref={fileInputRef}
            type="file"
            accept="image/*"
            onChange={onPickPhoto}
            className="hidden"
            data-testid="chat-photo-input"
          />
          <button
            type="button"
            onClick={() => fileInputRef.current?.click()}
            disabled={!ready || sending}
            aria-label="Send photo"
            className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-rose-soft text-lg text-rose transition active:scale-95 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-rose/40 disabled:opacity-60"
          >
            📷
          </button>
          <input
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            placeholder={ready ? "send 個信息畀佢…" : "載入緊…"}
            aria-label="信息內容"
            disabled={!ready}
            className="flex-1 rounded-full border border-line bg-cream px-4 py-2 outline-none focus:border-rose focus-visible:ring-2 focus-visible:ring-rose/40"
          />
          <button
            type="submit"
            disabled={!ready || !draft.trim() || sending}
            className="rounded-full bg-rose px-5 py-2 font-medium text-white transition active:scale-95 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-rose/40 disabled:opacity-60"
          >
            {sending ? "…" : "Send"}
          </button>
        </div>
      </form>
    </main>
  );
}

const Bubble = ({
  msg,
  mine,
  supabase,
  chatKey,
}: {
  msg: DecryptedMessage;
  mine: boolean;
  supabase: SupabaseClient;
  chatKey: Uint8Array | null;
}) => {
  const bubbleClasses = `max-w-[78%] rounded-2xl px-4 py-2 text-sm shadow-sm ${
    mine ? "rounded-br-md bg-rose text-white" : "rounded-bl-md bg-surface text-ink"
  }`;
  const stampClasses = `mt-1 text-[10px] ${mine ? "text-white/70" : "text-ink-soft"}`;

  // Render photo bubble (separate component handles async decrypt + blob URL).
  if (msg.payload?.kind === "photo" && msg.payload.mediaHandle && chatKey) {
    return (
      <div className={`flex ${mine ? "justify-end" : "justify-start"}`}>
        <div className={`${bubbleClasses} !p-1.5`}>
          <PhotoBubble
            mediaHandle={msg.payload.mediaHandle}
            supabase={supabase}
            chatKey={chatKey}
          />
          <p className={`${stampClasses} px-2 pb-1`}>
            {dayjs(msg.createdAt).format("HH:mm")}
          </p>
        </div>
      </div>
    );
  }

  // Text / kaomoji / other.
  const text =
    msg.payload === null
      ? "（解密失敗）"
      : msg.payload.kind === "text"
        ? (msg.payload.text ?? "")
        : msg.payload.kind === "video"
          ? "🎬 影片"
          : msg.payload.kind === "voice"
            ? "🎙️ 語音"
            : msg.payload.kind === "kaomoji"
              ? (msg.payload.text ?? "")
              : "（未知信息）";

  return (
    <div className={`flex ${mine ? "justify-end" : "justify-start"}`}>
      <div className={bubbleClasses}>
        <p className="whitespace-pre-wrap break-words">{text}</p>
        <p className={stampClasses}>{dayjs(msg.createdAt).format("HH:mm")}</p>
      </div>
    </div>
  );
};

const PhotoBubble = ({
  mediaHandle,
  supabase,
  chatKey,
}: {
  mediaHandle: string;
  supabase: SupabaseClient;
  chatKey: Uint8Array;
}) => {
  const [url, setUrl] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    let createdUrl: string | null = null;
    (async () => {
      try {
        const bytes = await downloadAndDecrypt(supabase, chatKey, mediaHandle);
        if (cancelled) return;
        createdUrl = bytesToBlobUrl(bytes, sniffMime(bytes));
        setUrl(createdUrl);
      } catch (e) {
        if (!cancelled) setErr(errMsg(e));
      }
    })();
    return () => {
      cancelled = true;
      if (createdUrl) URL.revokeObjectURL(createdUrl);
    };
  }, [mediaHandle, supabase, chatKey]);

  if (err) {
    return <p className="px-3 py-2 text-xs italic">📷 載入失敗 — {err}</p>;
  }
  if (!url) {
    return (
      <div className="flex h-40 w-60 items-center justify-center rounded-xl bg-cream-deep text-xs text-ink-soft">
        解密緊…
      </div>
    );
  }
  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img
      src={url}
      alt="encrypted photo"
      data-testid="chat-photo-image"
      className="block max-h-80 w-auto max-w-full rounded-xl object-cover"
    />
  );
};
