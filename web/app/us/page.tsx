"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { errMsg } from "@/lib/errors";
import { clearKeyPair } from "@/lib/crypto/keys";
import {
  E2EE_COPY,
  getOurDay,
  kk_ai_usage_get,
  setOurDay,
  type AiUsage,
} from "@/lib/kk/api";
import {
  STYLE_PACK_LABELS,
  clearRecent,
  getQuickReact,
  getRecent,
  getStylePack,
  kk_kaomoji_prefs_get,
  loadCatalogue,
  setQuickReact,
  setStylePack,
  type StylePack,
} from "@/lib/kk/kaomoji";

type Lang = "zh-Hant" | "en";

interface State {
  userId: string;
  myName: string;
  partnerName: string;
  isPaired: boolean;
}

export default function UsPage() {
  const router = useRouter();
  const [s, setS] = useState<State | null>(null);
  const [quota, setQuota] = useState<AiUsage | null>(null);
  const [lang, setLang] = useState<Lang>(() => {
    if (typeof window === "undefined") return "zh-Hant";
    try {
      const l = localStorage.getItem("kk.lang");
      if (l === "en" || l === "zh-Hant") return l;
    } catch {
      /* ignore */
    }
    return "zh-Hant";
  });
  const [ourDay, setOurDayState] = useState(() =>
    typeof window === "undefined" ? "" : getOurDay(),
  );
  const [style, setStyle] = useState<StylePack>(() =>
    typeof window === "undefined" ? "classic" : getStylePack(),
  );
  const [quick, setQuick] = useState<string[]>(["", "", "", "", "", ""]);
  const [recent, setRecent] = useState<string[]>([]);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);

  useEffect(() => {
    const supabase = createClient();
    (async () => {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) {
        router.push("/login");
        return;
      }
      const { data: profile, error: profileErr } = await supabase
        .from("users")
        .select("my_name, partner_name")
        .eq("id", user.id)
        .maybeSingle();
      if (profileErr) {
        setError(errMsg(profileErr));
        return;
      }
      if (!profile) {
        router.push("/onboarding");
        return;
      }
      const { data: couple } = await supabase
        .from("couples")
        .select("id")
        .or(`user_a_id.eq.${user.id},user_b_id.eq.${user.id}`)
        .maybeSingle();
      setS({
        userId: user.id,
        myName: profile.my_name,
        partnerName: profile.partner_name,
        isPaired: Boolean(couple),
      });
    })();
    void kk_ai_usage_get().then(setQuota);
    void (async () => {
      await kk_kaomoji_prefs_get();
      setStyle(getStylePack());
      const c = await loadCatalogue();
      setQuick(getQuickReact(c));
      setRecent(getRecent());
    })();
  }, [router]);

  const signOut = async () => {
    const supabase = createClient();
    await supabase.auth.signOut();
    clearKeyPair();
    router.push("/login");
  };

  const unpair = async () => {
    if (!s?.isPaired) return;
    if (!confirm("確定解除配對？傾計 key 會失效。")) return;
    setBusy(true);
    setError(null);
    try {
      const supabase = createClient();
      const { error } = await supabase.rpc("unpair_couple");
      if (error) throw error;
      setInfo("已解除配對");
      router.push("/pair");
    } catch (e) {
      setError(errMsg(e));
    } finally {
      setBusy(false);
    }
  };

  const deleteAccount = async () => {
    if (!confirmDelete) {
      setConfirmDelete(true);
      return;
    }
    setBusy(true);
    setError(null);
    try {
      const supabase = createClient();
      // Best-effort: sign out locally. Full account delete needs backend.
      // TODO: dedicated delete-account RPC
      await supabase.auth.signOut();
      clearKeyPair();
      router.push("/login");
    } catch (e) {
      setError(errMsg(e));
      setBusy(false);
    }
  };

  if (!s) {
    return (
      <main className="flex min-h-screen items-center justify-center text-ink-soft">
        載入緊…
      </main>
    );
  }

  return (
    <main className="mx-auto min-h-screen max-w-2xl pb-24">
      <header className="border-b border-line bg-surface/90 px-4 py-4 backdrop-blur">
        <h1 className="text-lg">
          <span className="kao mr-1">(ˆ∇ˆ)</span>我哋
        </h1>
        <p className="text-xs text-ink-soft">Us / settings</p>
      </header>

      <div className="space-y-4 p-4">
        <div className="rounded-3xl bg-surface p-5 text-center shadow-sm">
          <p className="kao text-2xl">♡</p>
          <h2 className="mt-2 text-lg">
            {s.myName} ♡ {s.partnerName}
          </h2>
          <p className="text-xs text-ink-soft">
            {s.isPaired ? "已配對 · Paired" : "未配對"}
          </p>
        </div>

        <div className="rounded-2xl border border-dashed border-line bg-cream px-4 py-3 text-xs text-ink-soft">
          <strong className="text-ink">已移除功能</strong>
          <br />
          時間簿／玩樂／meetup／紀念日功能已移除
        </div>

        <section className="overflow-hidden rounded-2xl bg-surface shadow-sm">
          <Row label="語言 · Language">
            <div className="flex rounded-full bg-cream-deep p-0.5 text-xs">
              {(["zh-Hant", "en"] as Lang[]).map((l) => (
                <button
                  key={l}
                  type="button"
                  className={`rounded-full px-3 py-1 ${lang === l ? "bg-rose text-white" : ""}`}
                  onClick={() => {
                    setLang(l);
                    localStorage.setItem("kk.lang", l);
                  }}
                >
                  {l === "zh-Hant" ? "粵語繁中" : "English"}
                </button>
              ))}
            </div>
          </Row>
          <Row label="主題 · Theme">
            <span className="text-sm text-ink-soft">淺色 Soft light</span>
          </Row>
          <Row label="AI 剩餘次數">
            <span className="text-sm">
              {quota ? `${quota.remaining} / ${quota.limit}（本月）` : "…"}
            </span>
          </Row>
        </section>

        <section className="rounded-2xl bg-surface p-4 shadow-sm">
          <div className="mb-2 flex justify-between text-sm">
            <span>你哋嘅日子（可選）</span>
            <span className="text-xs text-ink-soft">couples.anniversary_iso</span>
          </div>
          <input
            type="date"
            value={ourDay}
            onChange={(e) => {
              setOurDayState(e.target.value);
              setOurDay(e.target.value);
              // TODO: persist nullable couples.anniversary_iso
            }}
            className="w-full rounded-xl border border-line bg-cream px-3 py-2 text-sm"
          />
          <p className="mt-1 text-[11px] text-ink-soft">
            唔係「紀念日」功能；只係可選日子
          </p>
        </section>

        <section className="space-y-3 rounded-2xl bg-surface p-4 shadow-sm">
          <h3 className="text-sm font-medium">
            <span className="kao mr-1">(´∀｀)</span>顏文字偏好
          </h3>
          <p className="text-[11px] text-ink-soft">
            已同步 kk_kaomoji_prefs_*（localStorage 作 cache）
          </p>
          <div>
            <p className="text-xs font-medium">快捷反應 · ≤6</p>
            <div className="mt-1 grid grid-cols-3 gap-1">
              {quick.map((k, i) => (
                <input
                  key={i}
                  value={k}
                  onChange={(e) => {
                    const next = [...quick];
                    next[i] = e.target.value;
                    setQuick(next);
                    setQuickReact(next);
                  }}
                  className="kao rounded-lg border border-line bg-cream px-1 py-2 text-center text-xs"
                  placeholder={`#${i + 1}`}
                />
              ))}
            </div>
          </div>
          <div>
            <div className="flex items-center justify-between">
              <p className="text-xs font-medium">最近用過</p>
              <button
                type="button"
                className="text-[11px] text-rose"
                onClick={() => {
                  clearRecent();
                  setRecent([]);
                }}
              >
                清除
              </button>
            </div>
            <p className="mt-1 break-all text-xs text-ink-soft">
              {recent.length ? recent.slice(0, 8).join(" · ") : "—"}
            </p>
          </div>
          <div>
            <p className="mb-1 text-xs font-medium">風格包</p>
            <div className="flex flex-wrap gap-1">
              {(Object.keys(STYLE_PACK_LABELS) as StylePack[]).map((id) => (
                <button
                  key={id}
                  type="button"
                  onClick={() => {
                    setStyle(id);
                    setStylePack(id);
                  }}
                  className={`rounded-full px-3 py-1 text-xs ${
                    style === id ? "bg-rose text-white" : "bg-cream-deep"
                  }`}
                >
                  {STYLE_PACK_LABELS[id]}
                </button>
              ))}
            </div>
          </div>
        </section>

        <section className="rounded-2xl bg-surface p-4 text-xs leading-relaxed text-ink-soft shadow-sm">
          <p className="font-medium text-ink">加密同政策</p>
          <p className="mt-1">{E2EE_COPY}</p>
          <p className="mt-2">傾計訊息 48 小時後自動刪除（messages.expires_at + 排程 purge）。</p>
        </section>

        {error && <p className="rounded-xl bg-rose-soft px-3 py-2 text-sm text-rose">{error}</p>}
        {info && <p className="rounded-xl bg-mint px-3 py-2 text-sm">{info}</p>}

        <div className="space-y-2">
          {s.isPaired && (
            <button
              type="button"
              disabled={busy}
              onClick={() => void unpair()}
              className="w-full rounded-2xl border border-line py-3 text-sm"
            >
              解除配對 · Unpair
            </button>
          )}
          <button
            type="button"
            disabled={busy}
            onClick={() => void signOut()}
            className="w-full rounded-2xl border border-line py-3 text-sm"
          >
            登出
          </button>
          <button
            type="button"
            disabled={busy}
            onClick={() => void deleteAccount()}
            className={`w-full rounded-2xl py-3 text-sm ${
              confirmDelete ? "bg-ink text-white" : "border border-ink/20 text-ink"
            }`}
          >
            {confirmDelete ? "再按一次確認刪除帳號" : "刪除帳號（獨立確認）"}
          </button>
          {confirmDelete && (
            <button
              type="button"
              className="w-full text-xs text-ink-soft"
              onClick={() => setConfirmDelete(false)}
            >
              取消刪除
            </button>
          )}
        </div>
      </div>
    </main>
  );
}

const Row = ({
  label,
  children,
}: {
  label: string;
  children: React.ReactNode;
}) => (
  <div className="flex items-center justify-between gap-3 border-b border-line px-4 py-3 last:border-0">
    <span className="text-sm">{label}</span>
    {children}
  </div>
);
