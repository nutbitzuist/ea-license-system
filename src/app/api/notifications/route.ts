import { NextRequest, NextResponse } from "next/server"
import { prisma } from "@/lib/db"
import { getServerSession } from "next-auth"
import { authOptions } from "@/lib/auth"
import { notificationSettingsSchema } from "@/lib/validations"

// GET: Fetch notification settings for current user
export async function GET() {
    try {
        const session = await getServerSession(authOptions)
        if (!session?.user?.id) {
            return NextResponse.json(
                { success: false, message: "Unauthorized" },
                { status: 401 }
            )
        }

        // Get or create notification settings
        let settings = await prisma.notificationSettings.findUnique({
            where: { userId: session.user.id },
        })

        if (!settings) {
            settings = await prisma.notificationSettings.create({
                data: { userId: session.user.id },
            })
        }

        return NextResponse.json({
            success: true,
            settings: {
                telegramChatId: settings.telegramChatId,
                telegramUsername: settings.telegramUsername,
                telegramVerified: settings.telegramVerified,
                discordWebhook: settings.discordWebhook,
                notifyTradeOpen: settings.notifyTradeOpen,
                notifyTradeClose: settings.notifyTradeClose,
                notifyDailyPL: settings.notifyDailyPL,
                notifyDrawdown: settings.notifyDrawdown,
                drawdownThreshold: settings.drawdownThreshold,
                dailySummaryTime: settings.dailySummaryTime,
            },
        })
    } catch (error) {
        console.error("Get notification settings error:", error)
        return NextResponse.json(
            { success: false, message: "Failed to fetch settings" },
            { status: 500 }
        )
    }
}

// PATCH: Update notification settings
export async function PATCH(request: NextRequest) {
    try {
        const session = await getServerSession(authOptions)
        if (!session?.user?.id) {
            return NextResponse.json(
                { success: false, message: "Unauthorized" },
                { status: 401 }
            )
        }

        const body = await request.json()
        const validatedData = notificationSettingsSchema.parse(body)

        // Update or create settings
        const settings = await prisma.notificationSettings.upsert({
            where: { userId: session.user.id },
            update: {
                ...(validatedData.discordWebhook !== undefined && { discordWebhook: validatedData.discordWebhook }),
                ...(validatedData.notifyTradeOpen !== undefined && { notifyTradeOpen: validatedData.notifyTradeOpen }),
                ...(validatedData.notifyTradeClose !== undefined && { notifyTradeClose: validatedData.notifyTradeClose }),
                ...(validatedData.notifyDailyPL !== undefined && { notifyDailyPL: validatedData.notifyDailyPL }),
                ...(validatedData.notifyDrawdown !== undefined && { notifyDrawdown: validatedData.notifyDrawdown }),
                ...(validatedData.drawdownThreshold !== undefined && { drawdownThreshold: validatedData.drawdownThreshold }),
                ...(validatedData.dailySummaryTime !== undefined && { dailySummaryTime: validatedData.dailySummaryTime }),
            },
            create: {
                userId: session.user.id,
                ...validatedData,
            },
        })

        return NextResponse.json({
            success: true,
            message: "Settings updated",
            settings,
        })
    } catch (error) {
        console.error("Update notification settings error:", error)
        return NextResponse.json(
            { success: false, message: "Failed to update settings" },
            { status: 500 }
        )
    }
}
