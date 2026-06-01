"use client";

import { useState } from "react";
import { createClient } from "@/lib/supabase/client";

export default function LoginPage() {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const signInWithGoogle = async () => {
    setBusy(true);
    setError(null);
    const supabase = createClient();
    const { error } = await supabase.auth.signInWithOAuth({
      provider: "google",
      options: {
        redirectTo: `${window.location.origin}/auth/callback`,
      },
    });
    if (error) {
      setError(error.message);
      setBusy(false);
    }
    // On success Supabase redirects the page; no further work here.
  };

  // Anonymous "試玩" sign-in is a TEST affordance only. It is gated behind a
  // build-time flag so it is tree-shaken out of production builds — otherwise
  // anyone could bypass Google auth and spawn unlimited anon accounts.
  const testSigninEnabled = process.env.NEXT_PUBLIC_ENABLE_TEST_SIGNIN === "1";

  const signInAsTest = async () => {
    if (!testSigninEnabled) return;
    setBusy(true);
    setError(null);
    const supabase = createClient();
    const { error } = await supabase.auth.signInAnonymously();
    if (error) {
      setError(error.message);
      setBusy(false);
      return;
    }
    // Hard redirect so server middleware re-reads cookies and routes us.
    window.location.href = "/";
  };

  return (
    <main className="flex min-h-screen items-center justify-center p-6">
      <div className="float-in w-full max-w-sm rounded-3xl bg-surface p-8 shadow-xl">
        <div className="text-center">
          <p className="kao mb-2 text-lg">(˶◕ ᗜ ◕˶)</p>
          <h1 className="text-3xl text-ink">Us 我哋</h1>
          <p className="mt-1 text-sm text-ink-soft">兩個人嘅小天地</p>
        </div>

        <button
          onClick={signInWithGoogle}
          disabled={busy}
          className="mt-8 flex w-full items-center justify-center gap-3 rounded-2xl bg-rose px-5 py-3 font-medium text-white shadow-md transition active:scale-95 disabled:opacity-60"
        >
          <GoogleMark />
          {busy ? "正在登入…" : "用 Google 登入"}
        </button>

        {testSigninEnabled && (
          <button
            onClick={signInAsTest}
            disabled={busy}
            data-testid="test-signin"
            className="mt-3 w-full rounded-2xl border border-dashed border-rose/40 bg-cream px-5 py-2.5 text-sm font-medium text-rose transition active:scale-95 disabled:opacity-60"
          >
            🧪 試玩模式（匿名）
          </button>
        )}

        {error && (
          <p className="mt-4 rounded-xl bg-rose-soft px-4 py-2 text-sm text-rose">
            {error}
          </p>
        )}

        <p className="mt-6 text-center text-xs text-ink-soft">
          所有信息經 X25519 + AES-GCM 端對端加密。
          <br />
          只有你同伴侶睇得到。
        </p>
      </div>
    </main>
  );
}

const GoogleMark = () => (
  <svg width="20" height="20" viewBox="0 0 18 18" aria-hidden>
    <path
      fill="#fff"
      d="M17.64 9.2c0-.64-.06-1.25-.16-1.84H9v3.48h4.84a4.14 4.14 0 0 1-1.79 2.72v2.26h2.9c1.7-1.56 2.69-3.87 2.69-6.62z"
    />
    <path
      fill="#fff"
      d="M9 18c2.43 0 4.47-.8 5.96-2.18l-2.9-2.26c-.8.54-1.83.86-3.06.86-2.35 0-4.34-1.59-5.05-3.72H.96v2.33A8.997 8.997 0 0 0 9 18z"
      opacity=".95"
    />
    <path
      fill="#fff"
      d="M3.95 10.7A5.41 5.41 0 0 1 3.66 9c0-.59.1-1.16.29-1.7V4.96H.96A8.99 8.99 0 0 0 0 9c0 1.45.35 2.82.96 4.04l2.99-2.34z"
      opacity=".9"
    />
    <path
      fill="#fff"
      d="M9 3.58c1.32 0 2.51.45 3.44 1.35l2.58-2.58C13.46.89 11.43 0 9 0A8.997 8.997 0 0 0 .96 4.96L3.95 7.3C4.66 5.17 6.65 3.58 9 3.58z"
      opacity=".85"
    />
  </svg>
);
