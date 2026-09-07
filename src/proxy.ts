import { type NextRequest, NextResponse } from "next/server"

import { getTemporaryWorkspace } from "@/lib/access/temporary-workspace.server"
import { refreshSupabaseSession } from "@/lib/supabase/proxy"

export async function proxy(request: NextRequest) {
  if (await getTemporaryWorkspace()) {
    const pathname = request.nextUrl.pathname
    const response =
      pathname === "/auth" ||
      pathname.startsWith("/auth/") ||
      pathname === "/onboarding"
        ? NextResponse.redirect(new URL("/#", request.url), 303)
        : NextResponse.next()
    response.headers.set("Cache-Control", "private, no-store, max-age=0")
    response.headers.set("Referrer-Policy", "no-referrer")
    response.headers.set("X-Robots-Tag", "noindex, nofollow")
    return response
  }
  return refreshSupabaseSession(request)
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico|css|js|map|txt|xml)$).*)",
  ],
}
