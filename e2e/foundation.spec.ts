import { expect, test } from "@playwright/test"

test("loads the backend foundation dashboard", async ({ page }) => {
  await page.goto("/")

  await expect(page.getByText("FANTASY HUD", { exact: true })).toBeVisible()
  await expect(
    page.getByRole("heading", { level: 1, name: "Backend foundation" })
  ).toBeVisible()

  const table = page.getByRole("table", { name: "Foundation status" })
  await expect(table).toBeVisible()
  await expect(
    table.getByRole("row", {
      name: /Hosted development Configured Supabase GitHub integration/i,
    })
  ).toBeVisible()

  await expect(
    table.getByRole("row", {
      name: /Product database Not modeled Deferred to Task 003/i,
    })
  ).toBeVisible()

  await expect(
    page.getByRole("button", { name: /theme customizer/i })
  ).toHaveCount(0)
})
