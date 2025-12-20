import { NextRequest, NextResponse } from "next/server"
import { prisma } from "@/lib/db"
import { sendPasswordResetEmail, generateToken } from "@/lib/email"
import { z } from "zod"

const forgotPasswordSchema = z.object({
    email: z.string().email(),
})

export async function POST(request: NextRequest) {
    try {
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

        // Send email
        await sendPasswordResetEmail(email, token)

        return NextResponse.json({
            success: true,
            message: "If an account exists with this email, you will receive a password reset link.",
        })
    } catch (error) {
        console.error("Forgot password error:", error)
        return NextResponse.json(
            { error: "Failed to process request" },
            { status: 500 }
        )
    }
}
