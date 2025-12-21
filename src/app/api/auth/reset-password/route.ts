import { NextRequest, NextResponse } from "next/server"
import { hash } from "bcryptjs"
import { prisma } from "@/lib/db"
import { checkRateLimit, RATE_LIMITS } from "@/lib/rate-limit"
import { z } from "zod"

const resetPasswordSchema = z.object({
    token: z.string().min(1),
    password: z.string().min(8, "Password must be at least 8 characters").max(128, "Password too long"),
})

export async function POST(request: NextRequest) {
    try {
        // Rate limiting by IP
        const ip = request.headers.get("x-forwarded-for") || request.headers.get("x-real-ip") || "unknown"
        const rateLimitResult = checkRateLimit(`auth:reset:${ip}`, RATE_LIMITS.auth)
        if (!rateLimitResult.allowed) {
            return NextResponse.json(
                { error: "Too many requests. Please try again later." },
                { status: 429 }
            )
        }

        const body = await request.json()
        const { token, password } = resetPasswordSchema.parse(body)


        // Find valid token
        const resetToken = await prisma.passwordResetToken.findUnique({
            where: { token },
        })

        if (!resetToken) {
            return NextResponse.json(
                { error: "Invalid or expired reset link" },
                { status: 400 }
            )
        }

        // Check if token is expired
        if (resetToken.expiresAt < new Date()) {
            // Delete expired token
            await prisma.passwordResetToken.delete({
                where: { id: resetToken.id },
            })
            return NextResponse.json(
                { error: "Reset link has expired. Please request a new one." },
                { status: 400 }
            )
        }

        // Find user
        const user = await prisma.user.findUnique({
            where: { email: resetToken.email },
        })

        if (!user) {
            return NextResponse.json(
                { error: "User not found" },
                { status: 404 }
            )
        }

        // Hash new password
        const passwordHash = await hash(password, 12)

        // Update user password
        await prisma.user.update({
            where: { id: user.id },
            data: { passwordHash },
        })

        // Delete used token
        await prisma.passwordResetToken.delete({
            where: { id: resetToken.id },
        })

        return NextResponse.json({
            success: true,
            message: "Password has been reset successfully. You can now log in.",
        })
    } catch (error) {
        console.error("Reset password error:", error)
        if (error instanceof z.ZodError) {
            return NextResponse.json(
                { error: error.issues[0]?.message || "Validation failed" },
                { status: 400 }
            )
        }
        return NextResponse.json(
            { error: "Failed to reset password" },
            { status: 500 }
        )
    }
}
