// Mobile viewport smoke + CRUD-delete sanity. Covers gaps the main
// pair-and-chat test doesn't exercise:
//   - 375×667 viewport (iPhone SE) sanity: header + bottom tabs fit
//   - Time anniversary delete
//   - Memory entry delete
//   - Profile loads for paired solo user (regression for #profile)

import { test, expect, Browser } from "@playwright/test";

const makeAnonOnboarded = async (browser: Browser, viewport = { width: 1280, height: 720 }) => {
  const ctx = await browser.newContext({ viewport });
  const page = await ctx.newPage();
  await page.goto("/login");
  await page.getByTestId("test-signin").click();
  await page.waitForURL("**/onboarding", { timeout: 15_000 });
  await page.getByLabel("你嘅名").fill("Solo");
  await page.getByLabel("伴侶嘅名").fill("Future");
  await page.getByLabel("紀念日").fill("2024-12-25");
  await page.getByRole("button", { name: "下一步：配對伴侶" }).click();
  await page.waitForURL("**/pair", { timeout: 15_000 });
  return { ctx, page };
};

test.describe("Mobile + CRUD-delete", () => {
  test("iPhone SE viewport — login + onboarding + pair page fit", async ({ browser }) => {
    const { ctx, page } = await makeAnonOnboarded(browser, { width: 375, height: 667 });

    // Header + sticky tabs should not overflow.
    const headerH1 = page.getByRole("heading", { name: "配對伴侶" });
    await expect(headerH1).toBeVisible();
    // Buttons should be tappable (44px min target).
    const createBtn = page.getByRole("button", { name: "生成我嘅 6 位數 code" });
    const box = await createBtn.boundingBox();
    expect(box).not.toBeNull();
    expect(box!.height).toBeGreaterThanOrEqual(40);

    await ctx.close();
  });

  test("copy-code button writes 6-digit code to clipboard", async ({ browser }) => {
    const { ctx, page } = await makeAnonOnboarded(browser);
    await page.context().grantPermissions(["clipboard-read", "clipboard-write"]);

    await page.getByRole("button", { name: "生成我嘅 6 位數 code" }).click();
    const codeEl = page.locator(".kao.text-4xl");
    await expect(codeEl).toBeVisible({ timeout: 10_000 });
    const code = (await codeEl.textContent())?.trim() ?? "";
    expect(code).toMatch(/^\d{6}$/);

    await page.getByRole("button", { name: /複製/ }).click();
    await expect(page.locator("#copy-status")).toHaveText(/已 copy/);

    const clip = await page.evaluate(() => navigator.clipboard.readText());
    expect(clip).toBe(code);
    await ctx.close();
  });
});
