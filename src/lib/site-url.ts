export interface SiteUrlEnvironment {
  NEXT_PUBLIC_SITE_URL?: string
  NEXT_PUBLIC_VERCEL_URL?: string
}

const allowedAuthRedirectPaths = new Set([
  "/auth/confirm",
  "/auth/update-password",
])

function parseHttpUrl(value: string, label: string): URL {
  let parsed: URL

  try {
    parsed = new URL(value)
  } catch {
    throw new Error(`${label} must be a valid absolute URL.`)
  }

  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
    throw new Error(`${label} must use the http: or https: protocol.`)
  }

  if (
    parsed.username ||
    parsed.password ||
    parsed.search ||
    parsed.hash ||
    parsed.pathname.replaceAll("/", "")
  ) {
    throw new Error(`${label} must be a plain site origin.`)
  }

  return parsed
}

export function resolveSiteUrl(environment: SiteUrlEnvironment): string {
  const configuredSiteUrl = environment.NEXT_PUBLIC_SITE_URL?.trim()

  if (configuredSiteUrl) {
    return parseHttpUrl(configuredSiteUrl, "NEXT_PUBLIC_SITE_URL").origin
  }

  const vercelHostname = environment.NEXT_PUBLIC_VERCEL_URL?.trim()
  if (vercelHostname) {
    const candidate = vercelHostname.includes("://")
      ? vercelHostname
      : `https://${vercelHostname}`
    return parseHttpUrl(candidate, "NEXT_PUBLIC_VERCEL_URL").origin
  }

  return "http://localhost:3000"
}

export function getSiteUrl(): string {
  return resolveSiteUrl({
    NEXT_PUBLIC_SITE_URL: process.env.NEXT_PUBLIC_SITE_URL,
    NEXT_PUBLIC_VERCEL_URL: process.env.NEXT_PUBLIC_VERCEL_URL,
  })
}

export function buildAuthRedirectUrl(path: string): string {
  let decodedPath: string
  try {
    decodedPath = decodeURIComponent(path)
  } catch {
    throw new Error("Auth redirect path must be valid URL text.")
  }

  if (decodedPath.includes("\\")) {
    throw new Error("Auth redirect path must be an internal path.")
  }

  const parsed = new URL(decodedPath, "https://internal.invalid")
  if (
    parsed.origin !== "https://internal.invalid" ||
    !allowedAuthRedirectPaths.has(parsed.pathname)
  ) {
    throw new Error("Auth redirect path is not allowed.")
  }

  return new URL(`${parsed.pathname}${parsed.search}`, getSiteUrl()).toString()
}
