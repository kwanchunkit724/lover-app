"use client";

import { useEffect, useMemo, useState } from "react";
import {
  filteredCategories,
  getRecent,
  loadCatalogue,
  pushRecent,
  type KaoCatalogue,
} from "@/lib/kk/kaomoji";

export function KaomojiPicker({
  open,
  onClose,
  onPick,
}: {
  open: boolean;
  onClose: () => void;
  onPick: (k: string) => void;
}) {
  const [cat, setCat] = useState<KaoCatalogue | null>(null);
  const [active, setActive] = useState<string>("");
  const [q, setQ] = useState("");
  const [recent, setRecent] = useState<string[]>([]);

  useEffect(() => {
    if (!open) return;
    void loadCatalogue().then((c) => {
      setCat(c);
      const cats = filteredCategories(c);
      setActive(cats[0]?.id ?? "");
      setRecent(getRecent());
    });
  }, [open]);

  const cats = useMemo(() => (cat ? filteredCategories(cat) : []), [cat]);
  const entries = useMemo(() => {
    if (!cat) return [];
    if (q.trim()) {
      const needle = q.trim();
      return cats.flatMap((c) => c.entries).filter((e) => e.includes(needle));
    }
    return cats.find((c) => c.id === active)?.entries ?? [];
  }, [cat, cats, active, q]);

  if (!open) return null;

  return (
    <div className="fixed inset-x-0 bottom-0 z-50 mx-auto max-w-2xl rounded-t-3xl border border-line bg-surface p-3 shadow-2xl">
      <div className="mb-2 flex items-center gap-2">
        <input
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="搜尋顏文字…"
          className="flex-1 rounded-xl border border-line bg-cream px-3 py-2 text-sm outline-none focus:border-rose"
        />
        <button type="button" onClick={onClose} className="rounded-xl px-3 py-2 text-sm text-ink-soft">
          ✕
        </button>
      </div>
      {recent.length > 0 && !q && (
        <div className="mb-2 flex flex-wrap gap-1">
          {recent.slice(0, 12).map((k) => (
            <button
              key={k}
              type="button"
              className="kao rounded-lg bg-cream-deep px-2 py-1 text-sm"
              onClick={() => {
                pushRecent(k);
                onPick(k);
              }}
            >
              {k}
            </button>
          ))}
        </div>
      )}
      {!q && (
        <div className="mb-2 flex gap-1 overflow-x-auto pb-1">
          {cats.map((c) => (
            <button
              key={c.id}
              type="button"
              onClick={() => setActive(c.id)}
              className={`shrink-0 rounded-full px-3 py-1 text-xs ${
                active === c.id ? "bg-rose text-white" : "bg-cream-deep text-ink-soft"
              }`}
            >
              {c.label_zh}
            </button>
          ))}
        </div>
      )}
      <div className="grid max-h-56 grid-cols-3 gap-1 overflow-y-auto sm:grid-cols-4">
        {entries.map((k) => (
          <button
            key={k}
            type="button"
            className="kao rounded-xl border border-line bg-cream px-1 py-2 text-sm hover:border-rose"
            onClick={() => {
              setRecent(pushRecent(k));
              onPick(k);
            }}
          >
            {k}
          </button>
        ))}
      </div>
    </div>
  );
}
