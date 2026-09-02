import { expect, test, type Page } from "@playwright/test"

const email = "task004-sleeper@example.test"
const password = "correct horse battery staple"

async function disableMotion(page: Page) {
  await page.evaluate(async () => {
    document.documentElement.classList.add("dark")
    await document.fonts.ready
  })
  await page.addStyleTag({
    content:
      "*, *::before, *::after { animation-duration: 0s !important; animation-delay: 0s !important; transition-duration: 0s !important; caret-color: transparent !important; }",
  })
}

test.describe.configure({ mode: "serial" })

test("connects and persists one canonical Sleeper identity", async ({
  page,
}) => {
  await page.goto("/auth/sign-up")
  await page.getByLabel("Display name").fill("Task 004 Test User")
  await page.getByLabel("Email").fill(email)
  await page.getByLabel("Password", { exact: true }).fill(password)
  await page.getByLabel("Confirm password").fill(password)
  await page.getByRole("button", { name: "Create account" }).click()

  await expect(page).toHaveURL(/\/onboarding$/)
  await expect(
    page.getByRole("heading", { name: "Connect a Sleeper account" })
  ).toBeVisible()

  await disableMotion(page)
  await expect(page).toHaveScreenshot("sleeper-onboarding-desktop.png", {
    animations: "disabled",
    fullPage: true,
  })
  await page.setViewportSize({ width: 390, height: 844 })
  await expect(page).toHaveScreenshot("sleeper-onboarding-mobile.png", {
    animations: "disabled",
    fullPage: true,
  })
  await page.setViewportSize({ width: 1280, height: 720 })

  await page.getByLabel("Sleeper username").fill("two words")
  await page.getByRole("button", { name: "Connect Sleeper account" }).click()
  await expect(
    page
      .getByRole("alert")
      .filter({ hasText: "Enter a valid Sleeper username." })
  ).toBeVisible()

  await page.getByLabel("Sleeper username").fill("missing-user")
  await page.getByRole("button", { name: "Connect Sleeper account" }).click()
  await expect(
    page.getByRole("alert").filter({ hasText: "Sleeper account not found." })
  ).toBeVisible()

  await page.getByLabel("Sleeper username").fill("@fixture-user-isolated")
  await page.getByRole("button", { name: "Connect Sleeper account" }).click()

  await expect(page).toHaveURL(/^http:\/\/127\.0\.0\.1:3101\/$/)
  await expect(page.getByText("Fixture Sleeper User")).toBeVisible()
  await expect(
    page
      .getByLabel("League discovery summary")
      .getByText("@CanonicalFixtureUser", { exact: true })
  ).toBeVisible()
  await expect(page.getByText("Sleeper account", { exact: true })).toBeVisible()
  await expect(page.getByText("Primary", { exact: true })).toBeVisible()
  await expect(page.getByText("Not started", { exact: true })).toBeVisible()

  await disableMotion(page)
  await expect(page).toHaveScreenshot("sleeper-connected-desktop.png", {
    animations: "disabled",
    fullPage: true,
  })
  await page.setViewportSize({ width: 390, height: 844 })
  await expect(page).toHaveScreenshot("sleeper-connected-mobile.png", {
    animations: "disabled",
    fullPage: true,
  })
  await page.setViewportSize({ width: 1280, height: 720 })

  await page.goto("/onboarding")
  await expect(page).toHaveURL(/^http:\/\/127\.0\.0\.1:3101\/$/)

  await page.getByRole("button", { name: "Sign out" }).click()
  await expect(page).toHaveURL(/\/auth\/sign-in$/)
  await page.getByLabel("Email").fill(email)
  await page.getByLabel("Password").fill(password)
  await page.getByRole("button", { name: "Sign in" }).click()

  await expect(page).toHaveURL(/^http:\/\/127\.0\.0\.1:3101\/$/)
  await expect(
    page
      .getByLabel("League discovery summary")
      .getByText("@CanonicalFixtureUser", { exact: true })
  ).toBeVisible()
  await expect(page.getByText("Not started", { exact: true })).toBeVisible()
})
