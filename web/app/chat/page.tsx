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
import {
  CHAT_BANNER_48H,
  CHAT_BANNER_E2EE,
  getMoodForToday,
} from "@/lib/kk/api";
import { getQuickReact, loadCatalogue } from "@/lib/kk/kaomoji";
import { KaomojiPicker } from "@/components/kk/KaomojiPicker";

type Ready = {
  coupleId: string;
  partnerId: string;
  partnerName: string;
  myId: string;
  chatKey: Uint8Array;
};

const MAX_PHOTO_BYTES = 8 * 1024 * 1024;
const RESYNC_MS = 10_000;

export default function ChatPage() {
  const router = useRouter();
  const [ready, setReady] = useState<Ready | null>(null);
  const [messages, setMessages] = useState<DecryptedMessage[]>([]);
  const [draft, setDraft] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [sending, setSending] = useState(false);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [pickerOpen, setPickerOpen] = useState(false);
  const [quick, setQuick] = useState<string[]>([]);
  const [reactFor, setReactFor] = useState<string | null>(null);
  const [supabase] = useState(() => createClient());
  const scrollerRef = useRef<HTMLDivElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (!getMoodForToday()) {
      router.replace("/mood");
      return;
    }
    void loadCatalogue().then((c) => setQuick(getQuickReact(c).filter(Boolean)));
  }, [router]);

  useEffect(() => {
    let cancelled = false;
    let unsub: (() => void) | undefined;
    let pollId: ReturnType<typeof setInterval> | undefined;

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

      const channel = subscribe(
        supabase,
        coupleId,
        chatKey,
        (msg) => mergeMessages([msg]),
        () => void resync(),
      );
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

  useEffect(() => {
    scrollerRef.current?.scrollTo({
      top: scrollerRef.current.scrollHeight,
      behavior: "smooth",
    });
  }, [messages.length]);

  const toggleSelect = (id: string) => {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const selectedTexts = () =>
    messages
      .filter((m) => selected.has(m.id) && m.payload?.kind === "text")
      .map((m) => m.payload?.text ?? "")
      .filter(Boolean);

  const mergeToMemory = () => {
    const texts = selectedTexts();
    if (!texts.length) return;
    const original = texts.join("\n");
    const title = original.slice(0, 24);
    const q = new URLSearchParams({
      merge: "1",
      original,
      title,
    });
    router.push(`/memory/new?${q.toString()}`);
  };

  const aiExpandSelected = () => {
    const texts = selectedTexts();
    if (!texts.length) return;
    // AI only gets user-submitted excerpts (never ciphertext) — hand off as draft text
    sessionStorage.setItem("kk.ai.draft", texts.join("\n"));
    router.push("/memory/ai");
  };

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
    e.target.value = "";
    if (!file || !ready || sending) return;
    if (file.size > MAX_PHOTO_BYTES) {
      setError(`檔案太大 (${Math.round(file.size / 1024 / 1024)} MB) — 上限 8 MB`);
      return;
    }
    setSending(true);
    setError(null);
    try {
      const bytes = new Uint8Array(await file.arrayBuffer());
      await sendPhoto(supabase, ready.coupleId, ready.myId, ready.chatKey, bytes);
    } catch (e) {
      setError(errMsg(e));
    } finally {
      setSending(false);
    }
  };

  return (
    <main className="flex h-screen flex-col pb-14">
      <header className="border-b border-line bg-surface/80 px-4 py-3 backdrop-blur">
        <div className="flex items-center justify-between">
          <h1 className="text-lg text-ink">
            <span className="kao mr-1">(´∀｀)</span>
            {ready ? `同 ${ready.partnerName}` : "載入緊…"}
          </h1>
          <span className="text-[10px] text-ink-soft">E2EE</span>
        </div>
      </header>

      <div className="bg-cream-deep px-3 py-2 text-center text-[11px] text-ink-soft">
        {CHAT_BANNER_48H}
        <br />
        {CHAT_BANNER_E2EE}
        <br />
        <span className="text-[10px]">MVP：未有媒體庫／匯出</span>
      </div>

      {error && (
        <button
          onClick={() => setError(null)}
          aria-label="關閉錯誤提示"
          className="flex w-full items-center justify-between gap-2 bg-rose-soft px-4 py-2 text-left text-sm text-rose"
        >
          <span>{error}</span>
          <span aria-hidden>✕</span>
        </button>
      )}

      {selected.size > 0 && (
        <div className="flex items-center gap-2 border-b border-line bg-surface px-3 py-2 text-xs">
          <span>已選 {selected.size} 則</span>
          <button
            type="button"
            className="rounded-full bg-rose px-3 py-1 text-white"
            onClick={mergeToMemory}
          >
            合併入記憶空間
          </button>
          <button
            type="button"
            className="rounded-full border border-line px-3 py-1"
            onClick={aiExpandSelected}
          >
            AI 整理／諗計劃
          </button>
          <button
            type="button"
            className="ml-auto text-ink-soft"
            onClick={() => setSelected(new Set())}
          >
            取消
          </button>
        </div>
      )}

      <div ref={scrollerRef} className="flex-1 overflow-y-auto px-4 py-4">
        <div className="mx-auto flex min-h-full max-w-2xl flex-col justify-end gap-2">
          {messages.map((m) => (
            <div key={m.id}>
              <Bubble
                msg={m}
                mine={ready?.myId === m.senderId}
                supabase={supabase}
                chatKey={ready?.chatKey ?? null}
                selected={selected.has(m.id)}
                onToggle={() => toggleSelect(m.id)}
                onLongPress={() => setReactFor(m.id)}
              />
              {reactFor === m.id && quick.length > 0 && (
                <div className="mt-1 flex flex-wrap gap-1">
                  {quick.slice(0, 6).map((k) => (
                    <button
                      key={k}
                      type="button"
                      className="kao rounded-lg bg-cream-deep px-2 py-1 text-sm"
                      onClick={() => {
                        setDraft((d) => d + k);
                        setReactFor(null);
                      }}
                    >
                      {k}
                    </button>
                  ))}
                </div>
              )}
            </div>
          ))}
          {messages.length === 0 && ready && (
            <p className="kao my-auto text-center text-ink-soft">
              (｡•ᴗ-)_ 仲未有信息，sayhi啦！
            </p>
          )}
        </div>
      </div>

      <form onSubmit={send} className="border-t border-line bg-surface px-3 py-3">
        <div className="mx-auto flex max-w-2xl items-center gap-2">
          <input
            ref={fileInputRef}
            type="file"
            accept="image/*,video/*,*/*"
            onChange={onPickPhoto}
            className="hidden"
            data-testid="chat-photo-input"
          />
          <button
            type="button"
            onClick={() => fileInputRef.current?.click()}
            disabled={!ready || sending}
            aria-label="Attach"
            className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-rose-soft text-sm text-rose disabled:opacity-60"
          >
            ＋
          </button>
          <button
            type="button"
            onClick={() => setPickerOpen(true)}
            aria-label="Kaomoji"
            className="kao flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-cream-deep text-xs"
          >
            (´∀｀)
          </button>
          <input
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            placeholder={ready ? "send 個信息畀佢…" : "載入緊…"}
            aria-label="信息內容"
            disabled={!ready}
            className="flex-1 rounded-full border border-line bg-cream px-4 py-2 outline-none focus:border-rose"
          />
          <button
            type="submit"
            disabled={!ready || !draft.trim() || sending}
            className="rounded-full bg-rose px-5 py-2 font-medium text-white disabled:opacity-60"
          >
            {sending ? "…" : "Send"}
          </button>
        </div>
      </form>

      <KaomojiPicker
        open={pickerOpen}
        onClose={() => setPickerOpen(false)}
        onPick={(k) => {
          setDraft((d) => d + k);
          setPickerOpen(false);
        }}
      />
    </main>
  );
}

const Bubble = ({
  msg,
  mine,
  supabase,
  chatKey,
  selected,
  onToggle,
  onLongPress,
}: {
  msg: DecryptedMessage;
  mine: boolean;
  supabase: SupabaseClient;
  chatKey: Uint8Array | null;
  selected: boolean;
  onToggle: () => void;
  onLongPress: () => void;
}) => {
  const pressTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const bubbleClasses = `max-w-[78%] rounded-2xl px-4 py-2 text-sm shadow-sm ${
    mine ? "rounded-br-md bg-rose text-white" : "rounded-bl-md bg-surface text-ink"
  } ${selected ? "ring-2 ring-ink" : ""}`;
  const stampClasses = `mt-1 text-[10px] ${mine ? "text-white/70" : "text-ink-soft"}`;

  const handlers = {
    onClick: () => onToggle(),
    onPointerDown: () => {
      pressTimer.current = setTimeout(onLongPress, 450);
    },
    onPointerUp: () => {
      if (pressTimer.current) clearTimeout(pressTimer.current);
    },
    onPointerLeave: () => {
      if (pressTimer.current) clearTimeout(pressTimer.current);
    },
  };

  if (msg.payload?.kind === "photo" && msg.payload.mediaHandle && chatKey) {
    return (
      <div className={`flex ${mine ? "justify-end" : "justify-start"}`} {...handlers}>
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
    <div className={`flex ${mine ? "justify-end" : "justify-start"}`} {...handlers}>
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

  if (err) return <p className="px-3 py-2 text-xs italic">📷 載入失敗 — {err}</p>;
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
