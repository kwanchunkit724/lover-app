// Photo send E2E — proves the encrypted Storage round-trip works
// between two browser contexts (Alice uploads encrypted PNG, Bob sees
// it in <img> after decrypt).

import { test, expect, Browser, BrowserContext, Page } from "@playwright/test";

type U = { ctx: BrowserContext; page: Page };

const makeUser = async (browser: Browser, name: string): Promise<U> => {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  page.on("console", (m) => {
    if (m.type() === "error" || m.type() === "warning") {
      console.log(`[${name}:${m.type()}]`, m.text());
    }
  });
  page.on("pageerror", (e) => console.log(`[${name}:pageerror]`, e.message));
  await page.goto("/login");
  await page.getByTestId("test-signin").click();
  await page.waitForURL("**/onboarding", { timeout: 15_000 });
  await page.getByLabel("你嘅名").fill(name);
  await page.getByLabel("伴侶嘅名").fill(name === "Alice" ? "Bob" : "Alice");
  await page.getByLabel("紀念日").fill("2024-02-14");
  await page.getByRole("button", { name: "下一步：配對伴侶" }).click();
  await page.waitForURL("**/pair", { timeout: 15_000 });
  return { ctx, page };
};

// A real PNG file (1x1 pink pixel) — valid magic bytes so the
// MIME-sniffer renders as image/png.
const PINK_PNG_BYTES = Buffer.from(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP8z8DwHwAFBQIA" +
    "X8jx0gAAAABJRU5ErkJggg==",
  "base64",
);

test("two anon users — photo upload + Realtime + decrypt-and-render", async ({ browser }) => {
  test.setTimeout(120_000);

  const alice = await makeUser(browser, "Alice");
  const bob = await makeUser(browser, "Bob");

  // Pair via code.
  await alice.page.getByRole("button", { name: "生成我嘅 6 位數 code" }).click();
  const code = (await alice.page.locator(".kao.text-4xl").textContent())?.trim() ?? "";
  expect(code).toMatch(/^\d{6}$/);

  await bob.page.getByRole("button", { name: "我有伴侶嘅 code" }).click();
  await bob.page.getByLabel("伴侶嘅 6 位數 code").fill(code);
  await bob.page.getByLabel("你哋嘅紀念日（兩邊要一樣）").fill("2024-02-14");
  await bob.page.getByRole("button", { name: "配對" }).click();
  await bob.page.waitForURL("**/chat", { timeout: 15_000 });
  await alice.page.waitForURL("**/chat", { timeout: 15_000 });

  // Wait for chat to fully initialize (ready=true) — Send button is
  // disabled until then. Use the photo button's :enabled state instead.
  await expect(alice.page.getByRole("button", { name: "Send photo" })).toBeEnabled({
    timeout: 15_000,
  });
  await expect(bob.page.getByRole("button", { name: "Send photo" })).toBeEnabled({
    timeout: 15_000,
  });

  // Alice uploads photo via the hidden file input.
  await alice.page.getByTestId("chat-photo-input").setInputFiles({
    name: "love.png",
    mimeType: "image/png",
    buffer: PINK_PNG_BYTES,
  });

  // Bob's chat should receive the photo bubble + decrypt it.
  // PhotoBubble adds data-testid="chat-photo-image" once decrypted.
  const bobPhoto = bob.page.getByTestId("chat-photo-image").first();
  await expect(bobPhoto).toBeVisible({ timeout: 20_000 });

  // Sanity: the <img> src should be a blob URL (created by URL.createObjectURL).
  const src = await bobPhoto.getAttribute("src");
  expect(src).toMatch(/^blob:/);

  // Alice should also see her own photo (echo via Realtime INSERT).
  const alicePhoto = alice.page.getByTestId("chat-photo-image").first();
  await expect(alicePhoto).toBeVisible({ timeout: 15_000 });

  await alice.ctx.close();
  await bob.ctx.close();
});
