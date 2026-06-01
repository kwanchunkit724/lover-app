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

export default function ChatPage() {
  const router = useRouter();
  const [ready, setReady] = useState<Ready | null>(null);
  const [messages, setMessages] = useState<DecryptedMessage[]>([]);
  const [draft, setDraft] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [sending, setSending] = useState(false);
  const supabaseRef = useRef(createClient());
  const scrollerRef = useRef<HTMLDivElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Bootstrap: pull session, couple, partner key; derive chat key.
  useEffect(() => {
    const supabase = supabaseRef.current;
    let cancelled = false;

    (async () => {
      try {
        const {
          data: { user },
        } = await supabase.auth.getUser();
        if (!user) {
          router.push("/login");
          return;
        }

        const { data: couple } = await supabase
          .from("couples")
          .select("id, user_a_id, user_b_id")
          .or(`user_a_id.eq.${user.id},user_b_id.eq.${user.id}`)
          .maybeSingle();
        if (!couple) {
          router.push("/pair");
          return;
        }
        const partnerId =
          couple.user_a_id === user.id ? couple.user_b_id : couple.user_a_id;

        const { data: partner } = await supabase
          .from("users")
          .select("my_name, public_key")
          .eq("id", partnerId)
          .maybeSingle();
        if (!partner?.public_key) {
          setError("伴侶仲未 set 好個 key，請佢登入一次先。");
          return;
        }

        const kp = loadKeyPair();
        if (!kp) {
          setError("本機冇 key — 請重新登入並完成 onboarding。");
          return;
        }

        const partnerPub = publicKeyFromBase64(partner.public_key);
        const chatKey = deriveChatKey(kp.privateKey, partnerPub, couple.id);

        if (cancelled) return;
        setReady({
          coupleId: couple.id,
          partnerId,
          partnerName: partner.my_name as string,
          myId: user.id,
          chatKey,
        });

        const mergeMessages = (incoming: DecryptedMessage[]) =>
          setMessages((prev) => {
            const seen = new Set(prev.map((m) => m.id));
            const fresh = incoming.filter((m) => !seen.has(m.id));
            if (fresh.length === 0) return prev;
            const merged = [...prev, ...fresh];
            merged.sort((a, b) => a.createdAt.localeCompare(b.createdAt));
            return merged;
          });

        // Subscribe FIRST, then fetch once the channel is live. This closes
        // the race where an INSERT lands between fetchInitial() and the
        // realtime handshake completing — previously that message was lost
        // on this client forever. onSubscribed also re-fires on reconnect,
        // resyncing anything missed during a dropped connection.
        const channel = subscribe(
          supabase,
          couple.id,
          chatKey,
          (msg) => mergeMessages([msg]),
          () => {
            void (async () => {
              try {
                const initial = await fetchInitial(supabase, couple.id, chatKey);
                if (!cancelled) mergeMessages(initial);
              } catch (e) {
                if (!cancelled) setError(errMsg(e));
              }
            })();
          },
        );

        return () => {
          void supabase.removeChannel(channel);
        };
      } catch (e) {
        if (!cancelled) setError(errMsg(e));
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [router]);

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
    try {
      await sendText(
        supabaseRef.current,
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
        supabaseRef.current,
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
          className="bg-rose-soft px-4 py-2 text-left text-sm text-rose"
        >
          {error} · 點 dismiss
        </button>
      )}

      <div
        ref={scrollerRef}
        className="flex-1 overflow-y-auto px-4 py-6"
      >
        <div className="mx-auto flex max-w-2xl flex-col gap-2">
          {messages.map((m) => (
            <Bubble
              key={m.id}
              msg={m}
              mine={ready?.myId === m.senderId}
              supabase={supabaseRef.current}
              chatKey={ready?.chatKey ?? null}
            />
          ))}
          {messages.length === 0 && ready && (
            <p className="kao mt-20 text-center text-ink-soft">
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
            className="rounded-full border border-line bg-cream px-3 py-2 text-lg transition active:scale-95 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-rose/40 disabled:opacity-60"
          >
            📷
          </button>
          <input
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            placeholder={ready ? "send 個信息畀佢…" : "載入緊…"}
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
