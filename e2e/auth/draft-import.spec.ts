import { expect, test } from "@playwright/test"

test("imports complete drafts from the connected account and restores the persisted summary", async ({
  page,
}, testInfo) => {
  test.setTimeout(120_000)
  await page.goto("/auth/sign-up")
  await page.getByLabel("Display name").fill("Draft import test")
  await page.getByLabel("Email").fill("draft-import-flow@example.test")
  await page
    .getByLabel("Password", { exact: true })
    .fill("correct horse battery staple")
  await page.getByLabel("Confirm password").fill("correct horse battery staple")
  await page.getByRole("button", { name: "Create account" }).click()
  await expect(page).toHaveURL(/\/onboarding$/)
  await page.getByLabel("Sleeper username").fill("draft-fixture")
  await page.getByRole("button", { name: "Connect Sleeper account" }).click()
  await page
    .getByRole("button", { name: "Import current-season leagues" })
    .click()
  await expect(page.getByText("League discovery complete.")).toBeVisible()
  await page.getByRole("link", { name: "Draft value" }).click()
  await page
    .getByRole("button", { name: "Import current-season drafts" })
    .click()
  await expect(
    page.getByText("Draft import complete.", { exact: true })
  ).toBeVisible()
  await expect(
    page.getByText("2 drafts imported", { exact: true })
  ).toBeVisible()
  await expect(page.getByText(/2 boards finalized/)).toBeVisible()
  await page.reload()
  await expect(
    page.getByText("2 drafts imported", { exact: true })
  ).toBeVisible()
  await expect(
    page.getByRole("button", { name: "Refresh current-season drafts" })
  ).toBeEnabled()
  await page
    .getByRole("button", { name: "Refresh current-season drafts" })
    .click()
  await expect(
    page.getByText("Draft import complete.", { exact: true })
  ).toBeVisible()
  await page.evaluate(async () => {
    document.documentElement.classList.add("dark")
    await document.fonts.ready
  })
  await page.setViewportSize({ width: 1440, height: 900 })
  await page.screenshot({
    path: testInfo.outputPath("draft-import-desktop.png"),
    animations: "disabled",
  })
  await page.setViewportSize({ width: 390, height: 844 })
  await page.screenshot({
    path: testInfo.outputPath("draft-import-mobile.png"),
    animations: "disabled",
  })
  await expect(
    page.getByRole("button", { name: "Refresh current-season drafts" })
  ).toBeVisible()
})
