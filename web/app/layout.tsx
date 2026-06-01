import type { Metadata } from "next";
import { Klee_One, Zen_Maru_Gothic, DM_Mono, Noto_Sans_TC } from "next/font/google";
import { TabBar } from "@/components/TabBar";
import { ToastProvider } from "@/components/Toast";
import "./globals.css";

// Brand fonts — match design-import/index.html.
const klee = Klee_One({
  weight: ["400", "600"],
  subsets: ["latin"],
  variable: "--font-klee",
  display: "swap",
});

const zenMaru = Zen_Maru_Gothic({
  weight: ["400", "500", "700"],
  subsets: ["latin"],
  variable: "--font-zen-maru",
  display: "swap",
});

const dmMono = DM_Mono({
  weight: ["400", "500"],
  subsets: ["latin"],
  variable: "--font-dm-mono",
  display: "swap",
});

const notoTC = Noto_Sans_TC({
  weight: ["400", "500", "600", "700"],
  subsets: ["latin"],
  variable: "--font-noto-tc",
  display: "swap",
});

export const metadata: Metadata = {
  title: "Us 我哋 — 兩個人嘅小天地",
  description: "情侶專屬封關係空間｜E2EE 加密信息、紀念日、協作記載",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html
      lang="zh-Hant"
      className={`${klee.variable} ${zenMaru.variable} ${dmMono.variable} ${notoTC.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col bg-cream text-ink font-body">
        <ToastProvider>
          <div className="flex flex-1 flex-col">{children}</div>
          <TabBar />
        </ToastProvider>
      </body>
    </html>
  );
}
