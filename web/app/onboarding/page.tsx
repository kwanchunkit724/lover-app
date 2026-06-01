"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { errMsg } from "@/lib/errors";
import { ensureKeyPair, publicKeyToBase64 } from "@/lib/crypto/keys";

export default function OnboardingPage() {
  const router = useRouter();
  const [myName, setMyName] = useState("");
  const [partnerName, setPartnerName] = useState("");
  const [anniversary, setAnniversary] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!myName || !partnerName || !anniversary) return;
    setBusy(true);
    setError(null);
    try {
      const supabase = createClient();
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error("no session");

      // Generate or recover keypair, upload public_key.
      const kp = ensureKeyPair();
      const pubB64 = publicKeyToBase64(kp.publicKey);

      const { error: upErr } = await supabase.from("users").insert({
        id: user.id,
        my_name: myName,
        partner_name: partnerName,
        anniversary_iso: anniversary,
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
      <form
        onSubmit={submit}
        className="float-in w-full max-w-md rounded-3xl bg-surface p-8 shadow-xl"
      >
        <div className="text-center">
          <p className="kao mb-2 text-lg">٩(ˊᗜˋ )و</p>
          <h1 className="text-2xl text-ink">先講低你哋嘅故事</h1>
          <p className="mt-1 text-sm text-ink-soft">呢啲資料只屬於你哋兩個</p>
        </div>

        <Field label="你嘅名" value={myName} onChange={setMyName} placeholder="例如：阿 Kit" />
        <Field label="伴侶嘅名" value={partnerName} onChange={setPartnerName} placeholder="例如：Michel" />
        <Field label="紀念日" value={anniversary} onChange={setAnniversary} type="date" />

        <button
          type="submit"
          disabled={busy || !myName || !partnerName || !anniversary}
          className="mt-6 w-full rounded-2xl bg-rose px-5 py-3 font-medium text-white shadow-md transition active:scale-95 disabled:opacity-60"
        >
          {busy ? "建立緊…" : "下一步：配對伴侶"}
        </button>

        {error && (
          <p className="mt-4 rounded-xl bg-rose-soft px-4 py-2 text-sm text-rose">
            {error}
          </p>
        )}
      </form>
    </main>
  );
}

const Field = ({
  label,
  value,
  onChange,
  type = "text",
  placeholder,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  type?: string;
  placeholder?: string;
}) => (
  <label className="mt-5 block">
    <span className="mb-1 block text-sm font-medium text-ink-soft">{label}</span>
    <input
      type={type}
      value={value}
      onChange={(e) => onChange(e.target.value)}
      placeholder={placeholder}
      className="w-full rounded-2xl border border-line bg-cream px-4 py-3 outline-none focus:border-rose"
      required
    />
  </label>
);
