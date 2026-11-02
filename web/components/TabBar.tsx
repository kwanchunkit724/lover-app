"use client";

// Bottom tab bar — KK: 對話 / 記憶空間 / 想你知道 / 我哋 (kaomoji icons)

import Link from "next/link";
import { usePathname } from "next/navigation";

const TABS = [
  { href: "/chat", label: "對話", icon: "(´∀｀)" },
  { href: "/memory", label: "記憶空間", icon: "♡" },
  { href: "/tell", label: "想你知道", icon: "(✧)" },
  { href: "/us", label: "我哋", icon: "(ˆ∇ˆ)" },
];

export const TabBar = () => {
  const pathname = usePathname();
  const visible = TABS.some((t) => pathname?.startsWith(t.href));
  if (!visible) return null;

  return (
    <nav className="sticky bottom-0 z-40 border-t border-line bg-surface/95 px-1 py-1 backdrop-blur">
      <ul className="mx-auto flex max-w-2xl justify-around">
        {TABS.map((t) => {
          const active = pathname?.startsWith(t.href);
          return (
            <li key={t.href} className="flex-1">
              <Link
                href={t.href}
                className={`flex flex-col items-center gap-0.5 rounded-xl py-2 text-[10px] transition ${
                  active ? "text-rose" : "text-ink-soft"
                }`}
              >
                <span className="kao text-base leading-none">{t.icon}</span>
                <span className="font-medium">{t.label}</span>
              </Link>
            </li>
          );
        })}
      </ul>
    </nav>
  );
};
