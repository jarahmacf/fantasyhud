import { expect, test } from "@playwright/test"

test("opens the selected live workspace in a fresh browser without a session", async ({
  page,
}) => {
  await page.goto("/")
  await expect(
    page.getByRole("heading", { name: "Sleeper leagues" })
  ).toBeVisible()
  await expect(
    page.getByText("Temporary Access League", { exact: true })
  ).toBeVisible()
  await expect(
    page.getByText("Unresolved Access League", { exact: true })
  ).toBeVisible()
  await expect(page.getByText("Private Account League")).toHaveCount(0)
  await expect(page.getByText("Temporary read-only access")).toBeVisible()
  await expect(
    page.getByRole("button", {
      name: /sign out|import leagues|refresh leagues/i,
    })
  ).toHaveCount(0)

  await page.goto("/rosters")
  await expect(
    page.getByRole("heading", { name: "Sleeper rosters" })
  ).toBeVisible()
  await expect(
    page.getByText("Temporary Fixture Team", { exact: true })
  ).toBeVisible()
  await expect(
    page.getByText("Temporary Fixture Player", { exact: true })
  ).toBeVisible()
  await expect(
    page.getByRole("button", { name: /import rosters|refresh rosters/i })
  ).toHaveCount(0)

  await page.goto("/players")
  await expect(
    page.getByRole("heading", { name: "Player catalog" })
  ).toBeVisible()
  await expect(
    page.getByRole("button", { name: /import.*catalog|refresh.*catalog/i })
  ).toHaveCount(0)
  await page.goto("/foundation")
  await expect(
    page.getByRole("heading", { name: "Repository foundation" })
  ).toBeVisible()
  await expect(page.getByRole("link", { name: /Rosters/i })).toBeVisible()
})

test("old login, invitation and password-reset destinations open the workspace", async ({
  page,
}) => {
  for (const path of [
    "/auth/sign-in",
    "/auth/sign-up",
    "/auth/forgot-password",
    "/auth/update-password",
    "/auth/error",
    "/auth/confirm?next=/auth/update-password#discarded-test-fragment",
    "/onboarding",
  ]) {
    await page.goto(path)
    await expect(
      page.getByRole("heading", { name: "Sleeper leagues" })
    ).toBeVisible()
    expect(new URL(page.url()).pathname).toBe("/")
    expect(new URL(page.url()).hash).toBe("")
    expect(page.url()).not.toContain("discarded-test-fragment")
    await expect(page.getByLabel("Password", { exact: true })).toHaveCount(0)
  }
})
