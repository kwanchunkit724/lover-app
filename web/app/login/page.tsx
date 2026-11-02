"use client";

import { useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { E2EE_COPY } from "@/lib/kk/api";

export default function LoginPage() {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [email, setEmail] = useState("");
  const [otpSent, setOtpSent] = useState(false);
  const [otp, setOtp] = useState("");

  const signInWithApple = async () => {
    setBusy(true);
    setError(null);
    const supabase = createClient();
    const { error } = await supabase.auth.signInWithOAuth({
      provider: "apple",
      options: {
        redirectTo: `${window.location.origin}/auth/callback`,
      },
    });
    if (error) {
      setError(error.message);
      setBusy(false);
    }
  };

  const sendOtp = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email.trim()) return;
    setBusy(true);
    setError(null);
    const supabase = createClient();
    const { error } = await supabase.auth.signInWithOtp({
      email: email.trim(),
      options: {
        emailRedirectTo: `${window.location.origin}/auth/callback`,
        shouldCreateUser: true,
      },
    });
    if (error) {
      setError(error.message);
      setBusy(false);
      return;
    }
    setOtpSent(true);
    setBusy(false);
  };

  const verifyOtp = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!otp.trim()) return;
    setBusy(true);
    setError(null);
    const supabase = createClient();
    const { error } = await supabase.auth.verifyOtp({
      email: email.trim(),
      token: otp.trim(),
      type: "email",
    });
    if (error) {
      setError(error.message);
      setBusy(false);
      return;
    }
    window.location.href = "/";
  };

  return (
    <main className="flex min-h-screen items-center justify-center p-6">
      <div className="float-in w-full max-w-sm rounded-3xl bg-surface p-8 shadow-xl">
        <div className="text-center">
          <p className="kao mb-2 text-2xl">( ˜ω˜)/</p>
          <h1 className="text-3xl text-ink">
            KK <span className="text-rose">♡</span>
          </h1>
          <p className="mt-1 text-sm text-ink-soft">for us · 情侶空間</p>
        </div>

        <button
          onClick={signInWithApple}
          disabled={busy}
          className="mt-8 flex w-full items-center justify-center gap-2 rounded-2xl bg-ink px-5 py-3 font-medium text-white shadow-md transition active:scale-95 disabled:opacity-60"
        >
          <span aria-hidden></span>
          {busy ? "正在登入…" : "使用 Apple 登入"}
        </button>
        <p className="mt-1 text-center text-[11px] text-ink-soft">Sign in with Apple</p>

        <div className="my-5 flex items-center gap-3 text-xs text-ink-soft">
          <div className="h-px flex-1 bg-line" />
          或 · or
          <div className="h-px flex-1 bg-line" />
        </div>

        {!otpSent ? (
          <form onSubmit={sendOtp} className="space-y-3">
            <label className="block text-sm font-medium text-ink-soft">
              電郵 OTP <span className="text-xs font-normal">Email one-time code</span>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="you@example.com"
                required
                className="mt-1 w-full rounded-2xl border border-line bg-cream px-4 py-3 outline-none focus:border-rose"
              />
            </label>
            <button
              type="submit"
              disabled={busy || !email.trim()}
              className="w-full rounded-2xl bg-rose px-5 py-3 font-medium text-white shadow-md transition active:scale-95 disabled:opacity-60"
            >
              {busy ? "傳送緊…" : "傳送驗證碼 · Send OTP"}
            </button>
          </form>
        ) : (
          <form onSubmit={verifyOtp} className="space-y-3">
            <p className="text-sm text-ink-soft">
              已傳送驗證碼去 <span className="font-medium text-ink">{email}</span>
            </p>
            <label className="block text-sm font-medium text-ink-soft">
              驗證碼
              <input
                inputMode="numeric"
                value={otp}
                onChange={(e) => setOtp(e.target.value)}
                placeholder="6 位數字"
                required
                className="mt-1 w-full rounded-2xl border border-line bg-cream px-4 py-3 tracking-widest outline-none focus:border-rose"
              />
            </label>
            <button
              type="submit"
              disabled={busy || !otp.trim()}
              className="w-full rounded-2xl bg-rose px-5 py-3 font-medium text-white shadow-md transition active:scale-95 disabled:opacity-60"
            >
              {busy ? "驗證緊…" : "登入"}
            </button>
            <button
              type="button"
              onClick={() => setOtpSent(false)}
              className="w-full text-center text-xs text-ink-soft"
            >
              改電郵
            </button>
          </form>
        )}

        {error && (
          <p className="mt-4 rounded-xl bg-rose-soft px-4 py-2 text-sm text-rose">{error}</p>
        )}

        <p className="mt-6 text-center text-[11px] leading-relaxed text-ink-soft">{E2EE_COPY}</p>
      </div>
    </main>
  );
}
