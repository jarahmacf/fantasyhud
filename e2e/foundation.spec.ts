import { expect, test } from "@playwright/test"

test("loads the repository foundation dashboard", async ({ page }) => {
  await page.goto("/")

  await expect(page.getByText("FANTASY HUD", { exact: true })).toBeVisible()
  await expect(
    page.getByRole("heading", { level: 1, name: "Repository foundation" })
  ).toBeVisible()

  const table = page.getByRole("table", { name: "Foundation status" })
  await expect(table).toBeVisible()
  await expect(
    table.getByRole("row", {
      name: /Backend Not connected Deferred to Task 002/i,
    })
  ).toBeVisible()

  await expect(
    page.getByRole("button", { name: /theme customizer/i })
  ).toHaveCount(0)
})
