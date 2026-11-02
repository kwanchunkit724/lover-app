"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  getMoodForToday,
  kk_want_list,
  kk_want_mark_read,
  kk_want_delete,
  type WantYouKnowItem,
} from "@/lib/kk/api";

export default function TellPage() {
  const router = useRouter();
  const [items, setItems] = useState<WantYouKnowItem[]>([]);

  const reload = () => void kk_want_list().then(setItems);

  useEffect(() => {
    if (!getMoodForToday()) {
      router.replace("/mood");
      return;
    }
    reload();
  }, [router]);

  return (
    <main className="mx-auto min-h-screen max-w-2xl pb-24">
      <header className="border-b border-line bg-surface/90 px-4 py-4 backdrop-blur">
        <h1 className="text-lg">
          <span className="kao mr-1">(✧)</span>想你知道
        </h1>
        <p className="text-xs text-ink-soft">Want you to know · 雙方都刪先消失</p>
      </header>

      <div className="space-y-3 p-4">
        {items.length === 0 ? (
          <div className="py-16 text-center">
            <p className="kao text-2xl">(´･ω･`)</p>
            <p className="mt-2 text-sm text-ink-soft">暫時冇嘢想你知道</p>
          </div>
        ) : (
          items.map((t) => (
            <article
              key={t.id}
              className="rounded-2xl border border-line bg-surface p-4 shadow-sm"
              onClick={() => {
                if (!t.readByMe) void kk_want_mark_read(t.id).then(reload);
              }}
            >
              <div className="flex gap-3">
                <div className="kao shrink-0 text-sm">(´∀｀)</div>
                <div className="min-w-0 flex-1">
                  {t.title && <h3 className="font-medium">{t.title}</h3>}
                  <p className="mt-0.5 text-sm">{t.content}</p>
                  <p className="mt-2 text-[11px] text-ink-soft">
                    {t.deadline ? `限期 ${t.deadline}` : "無限期"}
                    {t.reminder ? " · 提醒開（09:00 HKT）" : " · 提醒關"}
                  </p>
                  <div className="mt-2 flex flex-wrap gap-2 text-[11px]">
                    <span className={t.readByMe ? "text-rose" : "text-ink-soft"}>
                      你 · {t.readByMe ? "已讀" : "未讀"}
                    </span>
                    <span className={t.readByPartner ? "text-rose" : "text-ink-soft"}>
                      對方 · {t.readByPartner ? "已讀" : "未讀"}
                    </span>
                  </div>
                  <button
                    type="button"
                    className="mt-2 text-[11px] text-ink-soft underline"
                    onClick={(e) => {
                      e.stopPropagation();
                      void kk_want_delete(t.id).then(reload);
                    }}
                  >
                    我刪除（對方都刪先消失）
                  </button>
                </div>
              </div>
            </article>
          ))
        )}
      </div>

      <Link
        href="/tell/new"
        className="fixed bottom-20 right-4 z-30 flex h-12 w-12 items-center justify-center rounded-full bg-rose text-2xl text-white shadow-lg"
        aria-label="新增"
      >
        ＋
      </Link>
    </main>
  );
}
