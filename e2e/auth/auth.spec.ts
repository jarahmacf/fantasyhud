import { expect, test, type Page } from "@playwright/test"

const email = "task003-auth@example.test"
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

test("creates an account, profile, and protected cookie session", async ({
  page,
}) => {
  await page.goto("/auth/sign-up")
  await page.getByLabel("Display name").fill("Task 003 Test User")
  await page.getByLabel("Email").fill(email)
  await page.getByLabel("Password", { exact: true }).fill(password)
  await page.getByLabel("Confirm password").fill(password)
  await page.getByRole("button", { name: "Create account" }).click()

  await expect(page).toHaveURL(/\/onboarding$/)
  await expect(
    page.getByRole("heading", { name: "Connect a Sleeper account" })
  ).toBeVisible()
  await expect(page.getByText("Task 003 Test User")).toBeVisible()
  await expect(page.getByText(email)).toBeVisible()
  await expect(
    page.getByRole("button", { name: "Connect Sleeper account" })
  ).toBeEnabled()

  await disableMotion(page)
  await expect(page).toHaveScreenshot("onboarding-desktop.png", {
    animations: "disabled",
    fullPage: true,
  })
  await page.setViewportSize({ width: 390, height: 844 })
  await expect(page).toHaveScreenshot("onboarding-mobile.png", {
    animations: "disabled",
    fullPage: true,
  })

  await page.getByRole("button", { name: "Sign out" }).click()
  await expect(page).toHaveURL(/\/auth\/sign-in$/)
  await page.goto("/onboarding")
  await expect(page).toHaveURL(/\/auth\/sign-in\?next=%2Fonboarding$/)

  await page.getByLabel("Email").fill(email)
  await page.getByLabel("Password").fill(password)
  await page.getByRole("button", { name: "Sign in" }).click()
  await expect(page).toHaveURL(/\/onboarding$/)
  await expect(page.getByText("Task 003 Test User")).toBeVisible()

  await page.getByRole("button", { name: "Sign out" }).click()
  await page.goto("/auth/forgot-password")
  await page.getByLabel("Email").fill(email)
  await page.getByRole("button", { name: "Send reset instructions" }).click()
  await expect(
    page
      .getByRole("alert")
      .filter({ hasText: "If an account matches that address" })
  ).toBeVisible()

  await page.goto("/auth/sign-in?next=https%3A%2F%2Fattacker.test")
  await page.getByLabel("Email").fill(email)
  await page.getByLabel("Password").fill(password)
  await page.getByRole("button", { name: "Sign in" }).click()
  await expect(page).toHaveURL(/\/onboarding$/)
  await expect(page).not.toHaveURL(/attacker\.test/)
})

test("rejects an invalid recovery token without retaining secrets", async ({
  page,
}) => {
  await page.goto(
    "/auth/confirm?token_hash=invalid-secret-value&type=recovery&next=%2Fauth%2Fupdate-password"
  )
  await expect(page).toHaveURL(/\/auth\/error$/)
  expect(page.url()).not.toContain("token_hash")
  expect(page.url()).not.toContain("invalid-secret-value")
})
