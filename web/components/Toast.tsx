"use client";

// Auto-dismissing toast hook + portal-free renderer. Replaces inline
// alert banners — those caused page-jank when error state appeared.
//
// Usage:
//   const toast = useToast();
//   toast.show("已儲存");                    // success (mint bg)
//   toast.show("出咗錯", { kind: "error" });  // error (rose bg)
//
// Render <ToastViewport /> once in a layout to display them.

import { createContext, useCallback, useContext, useEffect, useState } from "react";

type Kind = "info" | "error" | "success";
interface ToastItem {
  id: number;
  message: string;
  kind: Kind;
}

interface Ctx {
  show: (message: string, opts?: { kind?: Kind; durationMs?: number }) => void;
}

const ToastCtx = createContext<Ctx | null>(null);
let nextId = 1;

export const ToastProvider = ({ children }: { children: React.ReactNode }) => {
  const [items, setItems] = useState<ToastItem[]>([]);

  const show: Ctx["show"] = useCallback((message, opts) => {
    const id = nextId++;
    const kind = opts?.kind ?? "info";
    const durationMs = opts?.durationMs ?? 3000;
    setItems((prev) => [...prev, { id, message, kind }]);
    if (durationMs > 0) {
      setTimeout(() => {
        setItems((prev) => prev.filter((t) => t.id !== id));
      }, durationMs);
    }
  }, []);

  return (
    <ToastCtx.Provider value={{ show }}>
      {children}
      <ToastViewport items={items} onDismiss={(id) =>
        setItems((prev) => prev.filter((t) => t.id !== id))
      } />
    </ToastCtx.Provider>
  );
};

export const useToast = (): Ctx => {
  const ctx = useContext(ToastCtx);
  if (!ctx) throw new Error("useToast must be used inside <ToastProvider>");
  return ctx;
};

const ToastViewport = ({
  items,
  onDismiss,
}: {
  items: ToastItem[];
  onDismiss: (id: number) => void;
}) => (
  <div
    role="status"
    aria-live="polite"
    className="pointer-events-none fixed top-4 left-1/2 z-[100] flex w-full max-w-sm -translate-x-1/2 flex-col gap-2 px-4"
  >
    {items.map((t) => (
      <ToastCard key={t.id} item={t} onDismiss={() => onDismiss(t.id)} />
    ))}
  </div>
);

const ToastCard = ({
  item,
  onDismiss,
}: {
  item: ToastItem;
  onDismiss: () => void;
}) => {
  const [mounted, setMounted] = useState(false);
  useEffect(() => {
    const id = requestAnimationFrame(() => setMounted(true));
    return () => cancelAnimationFrame(id);
  }, []);

  const colour =
    item.kind === "error"
      ? "bg-rose-soft text-rose"
      : item.kind === "success"
        ? "bg-mint text-ink"
        : "bg-surface text-ink";

  return (
    <button
      onClick={onDismiss}
      className={`pointer-events-auto rounded-2xl px-4 py-3 text-sm shadow-lg transition ${colour} ${
        mounted ? "translate-y-0 opacity-100" : "-translate-y-2 opacity-0"
      }`}
    >
      {item.message}
    </button>
  );
};
