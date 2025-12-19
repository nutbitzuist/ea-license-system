import { NextResponse } from "next/server"
import type { NextRequest } from "next/server"
import { getToken } from "next-auth/jwt"

export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl

  // Get the token from the session
  const token = await getToken({
    req: request,
    secret: process.env.NEXTAUTH_SECRET,
  })
  const isLoggedIn = !!token

  // Public routes that don't require authentication
  const publicRoutes = ["/", "/login", "/register", "/api/auth", "/api/validate"]
  const isPublicRoute = publicRoutes.some((route) => pathname === "/" ? pathname === route : pathname.startsWith(route))

  // API routes that need special handling
  if (pathname.startsWith("/api/")) {
    // Validate API is public (uses API key auth)
    if (pathname === "/api/validate") {
      return NextResponse.next()
    }

    // Auth routes are public
    if (pathname.startsWith("/api/auth")) {
      return NextResponse.next()
    }

    // Admin API routes require admin role
    if (pathname.startsWith("/api/admin")) {
      if (!isLoggedIn) {
        return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
      }
      if (token?.role !== "ADMIN") {
        return NextResponse.json({ error: "Forbidden" }, { status: 403 })
      }
    }

    // Other API routes require authentication
    if (!isLoggedIn && !isPublicRoute) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
    }

    return NextResponse.next()
  }

  // Redirect unauthenticated users to login
  if (!isLoggedIn && !isPublicRoute) {
    const loginUrl = new URL("/login", request.nextUrl.origin)
    loginUrl.searchParams.set("callbackUrl", pathname)
    return NextResponse.redirect(loginUrl)
  }

  // Redirect authenticated users away from auth pages
  if (isLoggedIn && (pathname === "/login" || pathname === "/register")) {
    return NextResponse.redirect(new URL("/dashboard", request.nextUrl.origin))
  }

  // Admin routes require admin role
  if (pathname.startsWith("/admin") && token?.role !== "ADMIN") {
    return NextResponse.redirect(new URL("/dashboard", request.nextUrl.origin))
  }

  return NextResponse.next()
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|.*\\.png$|.*\\.jpg$|.*\\.svg$).*)",
  ],
}
