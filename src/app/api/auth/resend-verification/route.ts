import { NextResponse } from "next/server"
import { getServerSession } from "next-auth"
import { authOptions } from "@/lib/auth"
import { prisma } from "@/lib/db"
import { sendVerificationEmail, generateToken } from "@/lib/email"

export async function POST() {
    try {
        const session = await getServerSession(authOptions)

        // Check if user is logged in
        if (!session?.user?.email) {
            return NextResponse.json(
                { error: "You must be logged in to resend verification" },
                { status: 401 }
            )
        }

        const email = session.user.email

        // Check if already verified
        const user = await prisma.user.findUnique({
            where: { email },
        })

        if (!user) {
            return NextResponse.json(
                { error: "User not found" },
                { status: 404 }
            )
        }

        if (user.emailVerified) {
            return NextResponse.json(
                { error: "Email is already verified" },
                { status: 400 }
            )
        }

        // Delete any existing verification tokens for this email
        await prisma.emailVerificationToken.deleteMany({
            where: { email },
        })

        // Generate new token
        const token = generateToken()
        const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000) // 24 hours

        // Save token
        await prisma.emailVerificationToken.create({
            data: {
                email,
                token,
                expiresAt,
            },
        })

        // Send email
        await sendVerificationEmail(email, token)

        return NextResponse.json({
            success: true,
            message: "Verification email sent. Please check your inbox.",
        })
    } catch (error) {
        console.error("Resend verification error:", error)
        return NextResponse.json(
            { error: "Failed to send verification email" },
            { status: 500 }
        )
    }
}
