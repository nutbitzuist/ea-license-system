import { NextRequest, NextResponse } from "next/server"
import { prisma } from "@/lib/db"
import { sendPasswordResetEmail, generateToken } from "@/lib/email"
import { checkRateLimit, RATE_LIMITS } from "@/lib/rate-limit"
import { z } from "zod"

const forgotPasswordSchema = z.object({
    email: z.string().email(),
})

export async function POST(request: NextRequest) {
    try {
        // Rate limiting by IP
        const ip = request.headers.get("x-forwarded-for") || request.headers.get("x-real-ip") || "unknown"
        const rateLimitResult = checkRateLimit(`auth:forgot:${ip}`, RATE_LIMITS.auth)
        if (!rateLimitResult.allowed) {
            return NextResponse.json(
                { error: "Too many requests. Please try again later." },
                { status: 429 }
            )
        }

        const body = await request.json()
        const { email } = forgotPasswordSchema.parse(body)


        // Find user by email
        const user = await prisma.user.findUnique({
            where: { email },
        })

        // Always return success to prevent email enumeration
        if (!user) {
            return NextResponse.json({
                success: true,
                message: "If an account exists with this email, you will receive a password reset link.",
            })
        }

        // Delete any existing reset tokens for this email
        await prisma.passwordResetToken.deleteMany({
            where: { email },
        })

        // Generate new token
        const token = generateToken()
        const expiresAt = new Date(Date.now() + 60 * 60 * 1000) // 1 hour

        // Save token
        await prisma.passwordResetToken.create({
            data: {
                email,
                token,
                expiresAt,
            },
        })

        // Send email - catch email errors separately so token is still created
        try {
            const result = await sendPasswordResetEmail(email, token)
            if (!result.success) {
                console.error("Email send failed:", result.error)
            }
        } catch (emailError) {
            console.error("Email service error:", emailError)
            // Continue anyway - token is created, user can try again
        }

        return NextResponse.json({
            success: true,
            message: "If an account exists with this email, you will receive a password reset link.",
        })
    } catch (error) {
        console.error("Forgot password error:", error)

        // Return more specific error info for debugging
        const errorMessage = error instanceof Error ? error.message : "Unknown error"

        return NextResponse.json(
            { error: "Failed to process request", details: errorMessage },
            { status: 500 }
        )
    }
}
