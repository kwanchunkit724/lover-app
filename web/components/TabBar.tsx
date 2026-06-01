"use client";

// Bottom tab bar — only renders on the four paired pages. Mirrors iOS
// HomeView TabView order: 對話 / 時間 / 紀念冊 / 我哋.

import Link from "next/link";
import { usePathname } from "next/navigation";

const TABS = [
  { href: "/chat", label: "對話", icon: "💬" },
  { href: "/time", label: "時間", icon: "🕒" },
  { href: "/memory", label: "紀念冊", icon: "📖" },
  { href: "/us", label: "我哋", icon: "💖" },
  { href: "/profile", label: "個人", icon: "👤" },
];

export const TabBar = () => {
  const pathname = usePathname();
  const visible = TABS.some((t) => pathname?.startsWith(t.href));
  if (!visible) return null;

  return (
    <nav className="sticky bottom-0 z-40 border-t border-line bg-surface/95 px-2 py-1 backdrop-blur">
      <ul className="mx-auto flex max-w-2xl justify-around">
        {TABS.map((t) => {
          const active = pathname?.startsWith(t.href);
          return (
            <li key={t.href} className="flex-1">
              <Link
                href={t.href}
                className={`flex flex-col items-center gap-0.5 rounded-xl py-2 text-[11px] transition ${
                  active ? "text-rose" : "text-ink-soft"
                }`}
              >
                <span className="text-xl">{t.icon}</span>
                <span>{t.label}</span>
              </Link>
            </li>
          );
        })}
      </ul>
    </nav>
  );
};
