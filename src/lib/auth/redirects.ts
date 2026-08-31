const defaultProtectedDestination = "/onboarding"

export function getSafeInternalNextPath(
  value: string | null | undefined,
  fallback = defaultProtectedDestination
): string {
  const candidate = value?.trim()
  if (!candidate) {
    return fallback
  }

  let decoded: string
  try {
    decoded = decodeURIComponent(candidate)
  } catch {
    return fallback
  }

  if (
    !decoded.startsWith("/") ||
    decoded.startsWith("//") ||
    decoded.includes("\\") ||
    /[\u0000-\u001f\u007f]/.test(decoded)
  ) {
    return fallback
  }

  const parsed = new URL(decoded, "https://internal.invalid")
  if (parsed.origin !== "https://internal.invalid") {
    return fallback
  }

  return `${parsed.pathname}${parsed.search}${parsed.hash}`
}
