// KK: anonymous / 試玩 login removed (Apple + Email OTP only).
// Full pair→chat e2e needs a test OTP harness or seeded sessions — skipped until then.
// Routes smoke-checked in simulation.spec / mobile-and-deletes where applicable.

import { test, expect } from "@playwright/test";

test.describe("KK auth surface (no anonymous)", () => {
  test("login shows Apple + Email OTP, no test-signin", async ({ page }) => {
    await page.goto("/login");
    await expect(page.getByRole("button", { name: /Apple/ })).toBeVisible();
    await expect(page.getByText(/電郵 OTP|Email/)).toBeVisible();
    await expect(page.getByTestId("test-signin")).toHaveCount(0);
    await expect(page.getByText(/試玩/)).toHaveCount(0);
  });

  test("legacy tabs redirected", async ({ page }) => {
    // Unauthenticated → bounced to login by middleware
    await page.goto("/time");
    await page.waitForURL(/\/login/);
    await page.goto("/profile");
    await page.waitForURL(/\/login/);
  });
});

test.describe("Full couple flow (anonymous users)", () => {
  test.skip(true, "Anonymous sign-in removed in KK; re-enable with Email OTP test harness");
  test("placeholder", async () => {
    /* skipped */
  });
});
