"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { errMsg } from "@/lib/errors";
import { ensureKeyPair, publicKeyToBase64 } from "@/lib/crypto/keys";

/** Pairing RPC still requires anniversary_iso on the users row (no backend change).
 *  Spec removed the anniversary onboarding step — we store a silent pairing default.
 *  Optional「你哋嘅日子」lives in 我哋 settings (mock until backend). */
const PAIRING_ANNIV_DEFAULT = "1970-01-01";

export default function OnboardingPage() {
  const router = useRouter();
  const [step, setStep] = useState(0);
  const [myName, setMyName] = useState("");
  const [partnerName, setPartnerName] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const submit = async () => {
    if (!myName || !partnerName) return;
    setBusy(true);
    setError(null);
    try {
      const supabase = createClient();
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) throw new Error("no session");

      const kp = ensureKeyPair();
      const pubB64 = publicKeyToBase64(kp.publicKey);

      const { error: upErr } = await supabase.from("users").insert({
        id: user.id,
        my_name: myName,
        partner_name: partnerName,
        anniversary_iso: PAIRING_ANNIV_DEFAULT,
        theme_id: "jbeam",
        public_key: pubB64,
      });
      if (upErr) throw upErr;

      router.push("/pair");
    } catch (e) {
      setError(errMsg(e));
      setBusy(false);
    }
  };

  return (
    <main className="flex min-h-screen items-center justify-center p-6">
      <div className="float-in w-full max-w-md rounded-3xl bg-surface p-8 shadow-xl">
        <div className="text-center">
          <p className="kao mb-2 text-lg">٩(ˊᗜˋ )و</p>
          <h1 className="text-2xl text-ink">歡迎嚟到 KK</h1>
          <p className="mt-1 text-sm text-ink-soft">Welcome · for the two of you</p>
        </div>

        <div className="mt-4 flex justify-center gap-2">
          {[0, 1, 2].map((i) => (
            <span
              key={i}
              className={`h-2 w-2 rounded-full ${i <= step ? "bg-rose" : "bg-line"}`}
            />
          ))}
        </div>

        {step === 0 && (
          <div className="mt-6 space-y-4 text-center">
            <p className="text-ink">呢度係你哋兩個嘅小天地。</p>
            <p className="text-sm text-ink-soft">
              傾計端對端加密；記憶同「想你知道」雙方共享。
            </p>
            <button
              type="button"
              onClick={() => setStep(1)}
              className="w-full rounded-2xl bg-rose px-5 py-3 font-medium text-white shadow-md"
            >
              下一步 · Next
            </button>
          </div>
        )}

        {step === 1 && (
          <div className="mt-6">
            <Field label="你嘅名" value={myName} onChange={setMyName} placeholder="例如：阿 Kit" />
            <div className="mt-4 flex gap-2">
              <button
                type="button"
                onClick={() => setStep(0)}
                className="flex-1 rounded-2xl border border-line py-3 text-sm"
              >
                返回
              </button>
              <button
                type="button"
                disabled={!myName}
                onClick={() => setStep(2)}
                className="flex-1 rounded-2xl bg-rose py-3 font-medium text-white disabled:opacity-60"
              >
                下一步
              </button>
            </div>
          </div>
        )}

        {step === 2 && (
          <div className="mt-6">
            <Field
              label="伴侶嘅名"
              value={partnerName}
              onChange={setPartnerName}
              placeholder="例如：Michel"
            />
            <p className="mt-3 text-xs text-ink-soft">
              ※ 冇紀念日步驟；可選「你哋嘅日子」之後喺「我哋」設定。
            </p>
            <div className="mt-4 flex gap-2">
              <button
                type="button"
                onClick={() => setStep(1)}
                className="flex-1 rounded-2xl border border-line py-3 text-sm"
              >
                返回
              </button>
              <button
                type="button"
                disabled={busy || !partnerName}
                onClick={() => void submit()}
                className="flex-1 rounded-2xl bg-rose py-3 font-medium text-white disabled:opacity-60"
              >
                {busy ? "建立緊…" : "開始配對"}
              </button>
            </div>
          </div>
        )}

        {error && (
          <p className="mt-4 rounded-xl bg-rose-soft px-4 py-2 text-sm text-rose">{error}</p>
        )}
      </div>
    </main>
  );
}

const Field = ({
  label,
  value,
  onChange,
  placeholder,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
}) => (
  <label className="block">
    <span className="mb-1 block text-sm font-medium text-ink-soft">{label}</span>
    <input
      type="text"
      value={value}
      onChange={(e) => onChange(e.target.value)}
      placeholder={placeholder}
      className="w-full rounded-2xl border border-line bg-cream px-4 py-3 outline-none focus:border-rose"
      required
    />
  </label>
);
