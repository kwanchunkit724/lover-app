"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { errMsg } from "@/lib/errors";

type Mode = "choose" | "showing-code" | "entering-code";

export default function PairPage() {
  const router = useRouter();
  const [mode, setMode] = useState<Mode>("choose");
  const [myCode, setMyCode] = useState<string | null>(null);
  const [enteredCode, setEnteredCode] = useState("");
  const [partnerAnniv, setPartnerAnniv] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Realtime: poll couples table — once paired, redirect to /chat.
  // Also pre-fill the partnerAnniv field from the caller's own profile
  // so they don't have to re-enter the date they typed at /onboarding.
  useEffect(() => {
    const supabase = createClient();
    let cancelled = false;

    const prefillAnniv = async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user || cancelled) return;
      const { data: profile } = await supabase
        .from("users")
        .select("anniversary_iso")
        .eq("id", user.id)
        .maybeSingle();
      if (!cancelled && profile?.anniversary_iso) {
        setPartnerAnniv(profile.anniversary_iso);
      }
    };
    void prefillAnniv();

    const check = async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user || cancelled) return;
      const { data: couple } = await supabase
        .from("couples")
        .select("id")
        .or(`user_a_id.eq.${user.id},user_b_id.eq.${user.id}`)
        .maybeSingle();
      if (couple && !cancelled) router.push("/chat");
    };
    const id = setInterval(check, 3000);
    void check();
    return () => {
      cancelled = true;
      clearInterval(id);
    };
  }, [router]);

  const createCode = async () => {
    setBusy(true);
    setError(null);
    try {
      const supabase = createClient();
      // create_pairing_code now requires the anniversary as an explicit
      // arg (see migration 0003). Read it from our own users row, which
      // was inserted at /onboarding.
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error("not_authenticated");
      const { data: profile, error: pErr } = await supabase
        .from("users")
        .select("anniversary_iso")
        .eq("id", user.id)
        .maybeSingle();
      if (pErr) throw pErr;
      if (!profile?.anniversary_iso) throw new Error("profile_missing");

      const { data, error } = await supabase.rpc("create_pairing_code", {
        p_anniversary_iso: profile.anniversary_iso,
      });
      if (error) throw error;
      setMyCode(data as string);
      setMode("showing-code");
    } catch (e) {
      setError(errMsg(e));
    } finally {
      setBusy(false);
    }
  };

  const redeemCode = async (e: React.FormEvent) => {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      const supabase = createClient();
      const { error } = await supabase.rpc("redeem_pairing_code", {
        p_code: enteredCode.trim(),
        p_anniversary_iso: partnerAnniv,
      });
      if (error) throw error;
      // Polling effect above will catch the new couple and redirect.
      router.push("/chat");
    } catch (e) {
      setError(errMsg(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <main className="flex min-h-screen items-center justify-center p-6">
      <div className="float-in w-full max-w-md rounded-3xl bg-surface p-8 shadow-xl">
        <div className="text-center">
          <p className="kao mb-2 text-lg">(◍•ᴗ•◍)❤</p>
          <h1 className="text-2xl text-ink">配對伴侶</h1>
          <p className="mt-1 text-sm text-ink-soft">一個人生成 code、一個人輸入</p>
        </div>

        {mode === "choose" && (
          <div className="mt-6 grid gap-3">
            <button
              onClick={createCode}
              disabled={busy}
              className="rounded-2xl bg-rose px-5 py-3 font-medium text-white shadow-md transition active:scale-95 disabled:opacity-60"
            >
              {busy ? "生成緊…" : "生成我嘅 6 位數 code"}
            </button>
            <button
              onClick={() => setMode("entering-code")}
              disabled={busy}
              className="rounded-2xl border border-line bg-cream px-5 py-3 font-medium text-ink transition active:scale-95"
            >
              我有伴侶嘅 code
            </button>
          </div>
        )}

        {mode === "showing-code" && myCode && (
          <div className="mt-6 text-center">
            <p className="text-sm text-ink-soft">畀呢個 code 你伴侶輸入：</p>
            <p className="kao my-3 text-4xl tracking-widest text-rose" aria-label={`配對碼 ${myCode}`}>{myCode}</p>
            <button
              onClick={async () => {
                try {
                  await navigator.clipboard.writeText(myCode);
                  setError(null);
                  // brief inline pulse via temporary myCode swap is heavy;
                  // simpler: append "已 copy" to mode-specific status line.
                  const el = document.getElementById("copy-status");
                  if (el) {
                    el.textContent = "已 copy ✓";
                    setTimeout(() => { if (el) el.textContent = ""; }, 1500);
                  }
                } catch {
                  setError("copy 失敗，請手動 select 個 code");
                }
              }}
              className="rounded-full border border-rose/40 bg-cream px-4 py-1.5 text-xs text-rose transition active:scale-95 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-rose/40"
            >
              📋 複製
            </button>
            <p id="copy-status" className="kao mt-2 text-xs text-rose" aria-live="polite"></p>
            <p className="mt-2 text-xs text-ink-soft">10 分鐘內有效。配對成功會自動入聊天室。</p>
            <button
              onClick={() => setMode("choose")}
              className="mt-4 text-sm text-rose underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-rose/40"
            >
              返回
            </button>
          </div>
        )}

        {mode === "entering-code" && (
          <form onSubmit={redeemCode} className="mt-6 grid gap-4">
            <label className="block">
              <span className="mb-1 block text-sm font-medium text-ink-soft">伴侶嘅 6 位數 code</span>
              <input
                inputMode="numeric"
                maxLength={6}
                value={enteredCode}
                onChange={(e) => setEnteredCode(e.target.value.replace(/\D/g, ""))}
                className="kao w-full rounded-2xl border border-line bg-cream px-4 py-3 text-2xl tracking-widest outline-none focus:border-rose"
                required
              />
            </label>
            <label className="block">
              <span className="mb-1 block text-sm font-medium text-ink-soft">你哋嘅紀念日（兩邊要一樣）</span>
              <input
                type="date"
                value={partnerAnniv}
                onChange={(e) => setPartnerAnniv(e.target.value)}
                className="w-full rounded-2xl border border-line bg-cream px-4 py-3 outline-none focus:border-rose"
                required
              />
            </label>
            <button
              type="submit"
              disabled={busy || enteredCode.length !== 6 || !partnerAnniv}
              className="rounded-2xl bg-rose px-5 py-3 font-medium text-white shadow-md transition active:scale-95 disabled:opacity-60"
            >
              {busy ? "配對中…" : "配對"}
            </button>
            <button
              type="button"
              onClick={() => setMode("choose")}
              className="text-sm text-rose underline"
            >
              返回
            </button>
          </form>
        )}

        {error && (
          <p className="mt-4 rounded-xl bg-rose-soft px-4 py-2 text-sm text-rose">
            {translateError(error)}
          </p>
        )}
      </div>
    </main>
  );
}

const translateError = (raw: string): string => {
  if (raw.includes("invalid_code")) return "Code 唔啱，請再 check 過。";
  if (raw.includes("code_expired")) return "Code 已經過期，請伴侶生成新嘅。";
  if (raw.includes("anniversary_mismatch")) return "紀念日唔啱對，請 confirm 同伴侶輸入嘅一致。";
  if (raw.includes("already_paired")) return "你哋已經配對咗。";
  if (raw.includes("cannot_pair_with_self")) return "唔可以自己同自己配對 (◍•﹏•)";
  return raw;
};
