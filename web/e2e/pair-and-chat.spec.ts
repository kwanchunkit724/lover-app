// Two-user E2E: full pair → chat → time → memory → us flow.
// Uses anonymous sign-ins (Supabase Auth → Allow anonymous sign-ins MUST
// be enabled) so no real Google accounts are needed.
//
// Each "user" is a separate Playwright BrowserContext with its own
// cookies + localStorage. Two contexts = two distinct ephemeral users.

import { test, expect, Browser, BrowserContext, Page } from "@playwright/test";

type U = { ctx: BrowserContext; page: Page };

const makeUser = async (browser: Browser, name: string): Promise<U> => {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  await page.goto("/login");
  await page.getByTestId("test-signin").click();
  // After anon sign-in we hard-redirect to "/", which routes to /onboarding.
  await page.waitForURL("**/onboarding", { timeout: 15_000 });

  // Anniversary fixed so both users match.
  await page.getByLabel("你嘅名").fill(name);
  await page.getByLabel("伴侶嘅名").fill(name === "Alice" ? "Bob" : "Alice");
  await page.getByLabel("紀念日").fill("2024-02-14");
  await page.getByRole("button", { name: "下一步：配對伴侶" }).click();
  await page.waitForURL("**/pair", { timeout: 15_000 });
  return { ctx, page };
};

test.describe("Full couple flow (anonymous users)", () => {
  test("two anon users pair, chat, time, memory, us", async ({ browser }) => {
    test.setTimeout(180_000);

    const alice = await makeUser(browser, "Alice");
    const bob = await makeUser(browser, "Bob");

    // ── PAIR ──────────────────────────────────────────────────────────
    // Alice creates code
    await alice.page.getByRole("button", { name: "生成我嘅 6 位數 code" }).click();
    const codeEl = alice.page.locator(".kao.text-4xl");
    await expect(codeEl).toBeVisible({ timeout: 10_000 });
    const code = (await codeEl.textContent())?.trim() ?? "";
    expect(code).toMatch(/^\d{6}$/);

    // Bob redeems
    await bob.page.getByRole("button", { name: "我有伴侶嘅 code" }).click();
    await bob.page.getByLabel("伴侶嘅 6 位數 code").fill(code);
    await bob.page.getByLabel("你哋嘅紀念日（兩邊要一樣）").fill("2024-02-14");
    await bob.page.getByRole("button", { name: "配對" }).click();
    await bob.page.waitForURL("**/chat", { timeout: 15_000 });

    // Alice auto-redirects via the polling effect.
    await alice.page.waitForURL("**/chat", { timeout: 15_000 });

    // ── CHAT ──────────────────────────────────────────────────────────
    const aliceHello = "hello from Alice 我哋 ❤";
    const bobReply = "Bob 回覆 ☆";

    await alice.page.getByPlaceholder(/send 個信息/).fill(aliceHello);
    await alice.page.getByRole("button", { name: "Send", exact: true }).click();

    // Bob sees Alice's message via Realtime
    await expect(bob.page.getByText(aliceHello)).toBeVisible({ timeout: 15_000 });

    // Bob replies
    await bob.page.getByPlaceholder(/send 個信息/).fill(bobReply);
    await bob.page.getByRole("button", { name: "Send", exact: true }).click();
    await expect(alice.page.getByText(bobReply)).toBeVisible({ timeout: 15_000 });

    // ── TIME ──────────────────────────────────────────────────────────
    await alice.page.getByRole("link", { name: /時間/ }).click();
    await alice.page.waitForURL("**/time");
    await alice.page.getByRole("button", { name: "＋ 新增" }).click();
    await alice.page.getByLabel("標題").fill("第一次拍拖");
    await alice.page.getByLabel("日期").fill("2024-02-14");
    await alice.page.getByLabel("Emoji").fill("🌹");
    await alice.page.getByRole("button", { name: "加入" }).click();
    await expect(alice.page.getByText("第一次拍拖")).toBeVisible({ timeout: 10_000 });

    // Bob lands on /time and sees the same anniversary
    await bob.page.getByRole("link", { name: /時間/ }).click();
    await bob.page.waitForURL("**/time");
    await expect(bob.page.getByText("第一次拍拖")).toBeVisible({ timeout: 15_000 });

    // ── MEMORY ────────────────────────────────────────────────────────
    await alice.page.getByRole("link", { name: /紀念冊/ }).click();
    await alice.page.waitForURL("**/memory");
    await alice.page.getByRole("button", { name: "＋ 新事件" }).click();
    await alice.page.getByLabel("標題").fill("天星小輪夜遊");
    await alice.page.getByLabel("日期").fill("2024-03-01");
    await alice.page.getByLabel("地點").fill("尖沙咀碼頭");
    await alice.page.getByLabel("備註").fill("第一次坐天星小輪一齊睇夜景");
    await alice.page.getByRole("button", { name: "加入" }).click();
    await expect(alice.page.getByText("天星小輪夜遊")).toBeVisible({ timeout: 10_000 });

    await bob.page.getByRole("link", { name: /紀念冊/ }).click();
    await bob.page.waitForURL("**/memory");
    await expect(bob.page.getByText("天星小輪夜遊")).toBeVisible({ timeout: 15_000 });

    // ── US (date-card deck) ───────────────────────────────────────────
    await alice.page.getByRole("link", { name: /我哋/ }).click();
    await alice.page.waitForURL("**/us");
    await alice.page.getByRole("button", { name: /抽張卡/ }).click();
    // Card dialog should show with two buttons: 再抽 / 完成 ✓
    await expect(alice.page.getByRole("button", { name: /完成/ })).toBeVisible({
      timeout: 10_000,
    });
    await alice.page.getByPlaceholder(/想寫返兩句/).fill("正！");
    await alice.page.getByRole("button", { name: /完成/ }).click();
    // History list should now have one entry
    await expect(alice.page.getByText("正！")).toBeVisible({ timeout: 10_000 });

    // Bob sees the same play-history entry on /us (realtime sync — regression
    // for the us tab previously having NO subscription at all).
    await bob.page.getByRole("link", { name: /我哋/ }).click();
    await bob.page.waitForURL("**/us");
    await expect(bob.page.getByText("正！")).toBeVisible({ timeout: 15_000 });

    // ── PROFILE ───────────────────────────────────────────────────────
    await alice.page.getByRole("link", { name: /個人/ }).click();
    await alice.page.waitForURL("**/profile");
    await expect(alice.page.getByText("Alice")).toBeVisible({ timeout: 5_000 });
    await expect(alice.page.getByText("Bob")).toBeVisible();
    await expect(alice.page.getByText(/已配對/)).toBeVisible();

    // Theme switch
    await alice.page.getByRole("button", { name: /Notion/ }).click();
    await expect(alice.page.getByText("已更新主題")).toBeVisible({ timeout: 5_000 });

    // ── UNPAIR (Alice) ───────────────────────────────────────────────
    alice.page.on("dialog", (d) => d.accept());
    await alice.page.getByRole("button", { name: "解除配對" }).click();
    await alice.page.waitForURL("**/pair", { timeout: 10_000 });

    // Bob's chat should eventually reflect the unpair on next navigation.
    await bob.page.getByRole("link", { name: /個人/ }).click();
    await bob.page.waitForURL("**/profile");
    await expect(bob.page.getByText(/未配對/)).toBeVisible({ timeout: 10_000 });

    // ── SIGN OUT (Alice) ──────────────────────────────────────────────
    await alice.page.goto("/profile");
    // Anon user with no couple — profile loads from /pair, but /profile
    // is still reachable. Sign out → land on /login.
    await alice.page.getByRole("button", { name: "登出" }).click();
    await alice.page.waitForURL("**/login", { timeout: 10_000 });

    await alice.ctx.close();
    await bob.ctx.close();
  });
});
