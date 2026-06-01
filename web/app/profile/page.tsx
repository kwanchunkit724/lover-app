"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import dayjs from "dayjs";
import { createClient } from "@/lib/supabase/client";
import { errMsg } from "@/lib/errors";
import { clearKeyPair } from "@/lib/crypto/keys";

interface State {
  userId: string;
  myName: string;
  partnerName: string;
  anniversaryISO: string;
  themeId: "jbeam" | "notion" | "cozy";
  isAnon: boolean;
  isPaired: boolean;
  email: string | null;
}

const THEMES: { id: State["themeId"]; label: string; emoji: string }[] = [
  { id: "jbeam", label: "光束", emoji: "🌟" },
  { id: "notion", label: "Notion", emoji: "📝" },
  { id: "cozy", label: "暖意", emoji: "🍯" },
];

export default function ProfilePage() {
  const router = useRouter();
  const supabaseRef = useRef(createClient());
  const [s, setS] = useState<State | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);

  const load = async () => {
    const supabase = supabaseRef.current;
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      router.push("/login");
      return;
    }
    const { data: profile, error: profileErr } = await supabase
      .from("users")
      .select("my_name, partner_name, anniversary_iso, theme_id")
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
    const { data: couple, error: coupleErr } = await supabase
      .from("couples")
      .select("id")
      .or(`user_a_id.eq.${user.id},user_b_id.eq.${user.id}`)
      .maybeSingle();
    if (coupleErr) {
      setError(errMsg(coupleErr));
      return;
    }
    setS({
      userId: user.id,
      myName: profile.my_name,
      partnerName: profile.partner_name,
      anniversaryISO: profile.anniversary_iso,
      themeId: profile.theme_id as State["themeId"],
      // Anon users have is_anonymous=true on the JWT. user_metadata may
      // also tell us, but is_anonymous on user is the canonical field.
      isAnon: Boolean((user as { is_anonymous?: boolean }).is_anonymous),
      isPaired: Boolean(couple),
      email: user.email ?? null,
    });
  };

  useEffect(() => {
    void load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const setTheme = async (id: State["themeId"]) => {
    if (!s) return;
    setBusy(true);
    setError(null);
    try {
      const supabase = supabaseRef.current;
      const { error } = await supabase.from("users").update({ theme_id: id }).eq("id", s.userId);
      if (error) throw error;
      setS({ ...s, themeId: id });
      setInfo("已更新主題");
      setTimeout(() => setInfo(null), 2000);
    } catch (e) {
      setError(errMsg(e));
    } finally {
      setBusy(false);
    }
  };

  const unpair = async () => {
    if (!confirm("確定要解除配對？信息歷史會 keep 住但 partner 唔再連到你。")) return;
    setBusy(true);
    setError(null);
    try {
      const { error } = await supabaseRef.current.rpc("unpair");
      if (error) throw error;
      router.push("/pair");
    } catch (e) {
      setError(errMsg(e));
    } finally {
      setBusy(false);
    }
  };

  const signOut = async () => {
    setBusy(true);
    try {
      await supabaseRef.current.auth.signOut();
      // Wipe local keypair too — partner won't be able to decrypt our
      // new session if we sign back in (we'll regenerate keys), and the
      // old keys aren't useful to us either without our couple_id.
      clearKeyPair();
      router.push("/login");
    } catch (e) {
      setError(errMsg(e));
      setBusy(false);
    }
  };

  if (!s) {
    return (
      <main className="flex min-h-screen items-center justify-center px-6">
        {error ? (
          <p className="rounded-2xl bg-rose-soft px-4 py-3 text-center text-sm text-rose">
            {error}
          </p>
        ) : (
          <p className="kao text-ink-soft">載入緊…</p>
        )}
      </main>
    );
  }

  return (
    <main className="mx-auto flex w-full max-w-2xl flex-1 flex-col gap-6 px-4 py-6">
      <header className="flex items-center justify-between border-b border-line pb-3">
        <h1 className="text-lg text-ink">我嘅資料</h1>
      </header>

      {s.isAnon && (
        <div className="rounded-2xl border border-dashed border-rose/40 bg-cream-deep px-4 py-3 text-sm text-ink-soft">
          🧪 試玩模式（匿名）— 登出後資料會冇晒，sign in Google 先可以保留。
        </div>
      )}

      {error && (
        <div className="rounded-2xl bg-rose-soft px-4 py-3 text-sm text-rose">{error}</div>
      )}
      {info && (
        <div className="rounded-2xl bg-mint px-4 py-3 text-sm text-ink">{info}</div>
      )}

      {/* Profile card */}
      <section className="rounded-3xl bg-surface p-6 shadow-sm">
        <Row label="我嘅名" value={s.myName} />
        <Row label="伴侶嘅名" value={s.partnerName} />
        <Row label="紀念日" value={s.anniversaryISO} />
        <Row label="一齊咗" value={`${dayjs().diff(dayjs(s.anniversaryISO), "day")} 日`} />
        {s.email && <Row label="Email" value={s.email} />}
        <Row label="配對狀態" value={s.isPaired ? "已配對 ❤" : "未配對"} />
      </section>

      {/* Theme picker */}
      <section className="rounded-3xl bg-surface p-6 shadow-sm">
        <h2 className="text-base font-medium text-ink">主題</h2>
        <div className="mt-3 grid grid-cols-3 gap-2">
          {THEMES.map((t) => (
            <button
              key={t.id}
              disabled={busy}
              onClick={() => setTheme(t.id)}
              className={`rounded-2xl border px-3 py-3 text-sm transition active:scale-95 ${
                s.themeId === t.id
                  ? "border-rose bg-rose-soft text-rose"
                  : "border-line bg-cream text-ink"
              }`}
            >
              <span className="block text-2xl">{t.emoji}</span>
              <span className="mt-1 block">{t.label}</span>
            </button>
          ))}
        </div>
      </section>

      {/* Danger zone */}
      <section className="rounded-3xl bg-surface p-6 shadow-sm">
        <h2 className="text-base font-medium text-ink">危險區</h2>
        <div className="mt-3 grid gap-2">
          {s.isPaired && (
            <button
              disabled={busy}
              onClick={unpair}
              className="rounded-2xl border border-rose/40 px-4 py-3 text-sm text-rose transition active:scale-95 disabled:opacity-60"
            >
              解除配對
            </button>
          )}
          <button
            disabled={busy}
            onClick={signOut}
            className="rounded-2xl border border-line bg-cream px-4 py-3 text-sm text-ink transition active:scale-95 disabled:opacity-60"
          >
            登出
          </button>
        </div>
      </section>
    </main>
  );
}

const Row = ({ label, value }: { label: string; value: string }) => (
  <div className="flex justify-between border-b border-line py-3 last:border-b-0">
    <span className="text-sm text-ink-soft">{label}</span>
    <span className="text-sm text-ink">{value}</span>
  </div>
);
