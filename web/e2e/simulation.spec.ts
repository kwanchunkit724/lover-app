// Two-person SIMULATION (not just assertions) — a realistic couple using
// every surface of the app end-to-end, capturing screenshots at each beat
// so a human can eyeball the real UX. Personas: 阿明 (Ming) + 小美 (Mei).
//
// Run against prod:  E2E_BASE_URL=https://lover-app-web.vercel.app npx playwright test simulation
// Screenshots land in web/sim-shots/.

import { test, expect, Browser, BrowserContext, Page } from "@playwright/test";
import path from "path";

type U = { ctx: BrowserContext; page: Page; name: string };

const SHOTS = path.join(process.cwd(), "sim-shots");
const ANNIV = "2023-05-20"; // 520 — "I love you" in Cantonese numerology

const shot = async (u: U, label: string) =>
  u.page.screenshot({ path: path.join(SHOTS, `${label}.png`), fullPage: true });

const onboard = async (browser: Browser, name: string, partner: string): Promise<U> => {
  const ctx = await browser.newContext({ viewport: { width: 390, height: 844 } }); // iPhone 14
  const page = await ctx.newPage();
  page.on("pageerror", (e) => console.log(`  ⚠ [${name}] pageerror:`, e.message));
  await page.goto("/login");
  await page.getByTestId("test-signin").click();
  await page.waitForURL("**/onboarding", { timeout: 20_000 });
  await page.getByLabel("你嘅名").fill(name);
  await page.getByLabel("伴侶嘅名").fill(partner);
  await page.getByLabel("紀念日").fill(ANNIV);
  await page.getByRole("button", { name: "下一步：配對伴侶" }).click();
  await page.waitForURL("**/pair", { timeout: 20_000 });
  return { ctx, page, name };
};

test("simulation: 阿明 + 小美 live a week in the app", async ({ browser }) => {
  test.setTimeout(240_000);

  // ── Day 0: both join ────────────────────────────────────────────────
  const ming = await onboard(browser, "阿明", "小美");
  const mei = await onboard(browser, "小美", "阿明");

  // ── Pair ────────────────────────────────────────────────────────────
  await ming.page.getByRole("button", { name: "生成我嘅 6 位數 code" }).click();
  const codeEl = ming.page.locator(".kao.text-4xl");
  await expect(codeEl).toBeVisible({ timeout: 10_000 });
  const code = (await codeEl.textContent())?.trim() ?? "";
  console.log(`  阿明 code = ${code}`);
  await shot(ming, "01-ming-code");

  await mei.page.getByRole("button", { name: "我有伴侶嘅 code" }).click();
  await mei.page.getByLabel("伴侶嘅 6 位數 code").fill(code);
  await mei.page.getByLabel("你哋嘅紀念日（兩邊要一樣）").fill(ANNIV);
  await mei.page.getByRole("button", { name: "配對" }).click();
  await mei.page.waitForURL("**/chat", { timeout: 20_000 });
  await ming.page.waitForURL("**/chat", { timeout: 20_000 });
  console.log("  ✓ paired");

  // ── Chat: a real conversation ───────────────────────────────────────
  const send = async (u: U, msg: string) => {
    await u.page.getByPlaceholder(/send 個信息/).fill(msg);
    await u.page.getByRole("button", { name: "Send", exact: true }).click();
  };
  await send(ming, "小美今晚想食咩？😋");
  await expect(mei.page.getByText("小美今晚想食咩？😋")).toBeVisible({ timeout: 15_000 });
  await send(mei, "想食日本菜～🍣 你揀間好嘅");
  await expect(ming.page.getByText("想食日本菜～🍣 你揀間好嘅")).toBeVisible({ timeout: 15_000 });
  await send(ming, "好！訂咗尖沙咀嗰間 8點 ❤");
  await expect(mei.page.getByText("好！訂咗尖沙咀嗰間 8點 ❤")).toBeVisible({ timeout: 15_000 });
  await shot(ming, "02-ming-chat");
  await shot(mei, "03-mei-chat");

  // ── Time: Ming logs their anniversary ───────────────────────────────
  await ming.page.getByRole("link", { name: /時間/ }).click();
  await ming.page.waitForURL("**/time");
  await ming.page.getByRole("button", { name: "＋ 新增" }).click();
  await ming.page.getByLabel("標題").fill("拍拖一週年");
  await ming.page.getByLabel("日期").fill(ANNIV);
  await ming.page.getByLabel("Emoji").fill("🌹");
  await ming.page.getByRole("button", { name: "加入" }).click();
  await expect(ming.page.getByText("拍拖一週年")).toBeVisible({ timeout: 10_000 });
  // Mei sees it via realtime
  await mei.page.getByRole("link", { name: /時間/ }).click();
  await mei.page.waitForURL("**/time");
  await expect(mei.page.getByText("拍拖一週年")).toBeVisible({ timeout: 15_000 });
  await shot(mei, "04-mei-time");

  // ── Memory: Mei records a trip ──────────────────────────────────────
  await mei.page.getByRole("link", { name: /紀念冊/ }).click();
  await mei.page.waitForURL("**/memory");
  await mei.page.getByRole("button", { name: "＋ 新事件" }).click();
  await mei.page.getByLabel("標題").fill("西貢一日遊");
  await mei.page.getByLabel("日期").fill("2024-06-15");
  await mei.page.getByLabel("地點").fill("西貢");
  await mei.page.getByLabel("備註").fill("租咗船仔出海，食海鮮，影咗好多相 📸");
  await mei.page.getByRole("button", { name: "加入" }).click();
  await expect(mei.page.getByText("西貢一日遊")).toBeVisible({ timeout: 10_000 });
  await shot(mei, "05-mei-memory");
  // Ming sees the memory too
  await ming.page.getByRole("link", { name: /紀念冊/ }).click();
  await ming.page.waitForURL("**/memory");
  await expect(ming.page.getByText("西貢一日遊")).toBeVisible({ timeout: 15_000 });

  // ── Us: Ming draws a date card, Mei sees it sync live ───────────────
  await ming.page.getByRole("link", { name: /我哋/ }).click();
  await ming.page.waitForURL("**/us");
  // Mei parks on /us first so we prove realtime (no reload).
  await mei.page.getByRole("link", { name: /我哋/ }).click();
  await mei.page.waitForURL("**/us");

  await ming.page.getByRole("button", { name: /抽張卡/ }).click();
  await expect(ming.page.getByRole("button", { name: /完成/ })).toBeVisible({ timeout: 10_000 });
  await shot(ming, "06-ming-card");
  await ming.page.getByPlaceholder(/想寫返兩句/).fill("一齊整咗甜品，好好玩 🍮");
  await ming.page.getByRole("button", { name: /完成/ }).click();
  await expect(ming.page.getByText("一齊整咗甜品，好好玩 🍮")).toBeVisible({ timeout: 10_000 });
  // Mei (already on /us) sees it appear via the new realtime subscription
  await expect(mei.page.getByText("一齊整咗甜品，好好玩 🍮")).toBeVisible({ timeout: 15_000 });
  console.log("  ✓ /us realtime sync confirmed (Mei saw it without reload)");
  await shot(mei, "07-mei-us-synced");

  // ── Profile: status + theme ─────────────────────────────────────────
  await ming.page.getByRole("link", { name: /個人/ }).click();
  await ming.page.waitForURL("**/profile");
  await expect(ming.page.getByText("阿明")).toBeVisible({ timeout: 5_000 });
  await expect(ming.page.getByText("小美")).toBeVisible();
  await expect(ming.page.getByText(/已配對/)).toBeVisible();
  await shot(ming, "08-ming-profile");

  await ming.ctx.close();
  await mei.ctx.close();
});
