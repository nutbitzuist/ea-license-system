import { NextRequest, NextResponse } from "next/server"
import { prisma } from "@/lib/db"

export async function GET(request: NextRequest) {
    try {
        const token = request.nextUrl.searchParams.get("token")

        if (!token) {
            return NextResponse.redirect(new URL("/login?error=missing_token", request.url))
        }

        // Find valid token
        const verificationToken = await prisma.emailVerificationToken.findUnique({
            where: { token },
        })

        if (!verificationToken) {
            return NextResponse.redirect(new URL("/login?error=invalid_token", request.url))
        }

        // Check if token is expired
        if (verificationToken.expiresAt < new Date()) {
            await prisma.emailVerificationToken.delete({
                where: { id: verificationToken.id },
            })
            return NextResponse.redirect(new URL("/login?error=expired_token", request.url))
        }

        // Find user and update
        const user = await prisma.user.findUnique({
            where: { email: verificationToken.email },
        })

        if (!user) {
            return NextResponse.redirect(new URL("/login?error=user_not_found", request.url))
        }

        // Update user as verified
        await prisma.user.update({
            where: { id: user.id },
            data: { emailVerified: new Date() },
        })

        // Delete used token
        await prisma.emailVerificationToken.delete({
            where: { id: verificationToken.id },
        })

        // Redirect to login with success message
        return NextResponse.redirect(new URL("/login?verified=true", request.url))
    } catch (error) {
        console.error("Email verification error:", error)
        return NextResponse.redirect(new URL("/login?error=verification_failed", request.url))
    }
}
