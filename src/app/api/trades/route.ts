"use server"

import { NextRequest, NextResponse } from "next/server"
import { prisma } from "@/lib/db"
import { tradeSubmitSchema } from "@/lib/validations"
import { checkRateLimit, RATE_LIMITS } from "@/lib/rate-limit"

// POST: Submit a new trade or update an existing one (from EA)
export async function POST(request: NextRequest) {
    try {
        const apiKey = request.headers.get("X-API-Key")

        if (!apiKey) {
            return NextResponse.json(
                { success: false, message: "Missing API Key" },
                { status: 401 }
            )
        }

        // Rate limiting
        const rateLimitResult = checkRateLimit(`trades:${apiKey}`, RATE_LIMITS.validation)
        if (!rateLimitResult.allowed) {
            return NextResponse.json(
                { success: false, message: "Rate limit exceeded" },
                { status: 429 }
            )
        }

        // Find user by API key
        const user = await prisma.user.findUnique({
            where: { apiKey },
        })

        if (!user || !user.isActive || !user.isApproved) {
            return NextResponse.json(
                { success: false, message: "Invalid or inactive user" },
                { status: 401 }
            )
        }

        // Parse and validate request body
        const body = await request.json()
        const validatedData = tradeSubmitSchema.parse(body)

        // Find the MT account
        const mtAccount = await prisma.mtAccount.findFirst({
            where: {
                userId: user.id,
                accountNumber: validatedData.accountNumber,
            },
        })

        if (!mtAccount) {
            return NextResponse.json(
                { success: false, message: "Account not registered" },
                { status: 403 }
            )
        }

        // Find EA if provided
        let eaId: string | null = null
        if (validatedData.eaCode) {
            const ea = await prisma.expertAdvisor.findUnique({
                where: { eaCode: validatedData.eaCode },
            })
            if (ea) {
                eaId = ea.id
            }
        }

        // Check if trade already exists (upsert)
        const existingTrade = await prisma.trade.findUnique({
            where: {
                userId_mtAccountId_ticket: {
                    userId: user.id,
                    mtAccountId: mtAccount.id,
                    ticket: validatedData.ticket,
                },
            },
        })

        let trade
        if (existingTrade) {
            // Update existing trade (e.g., when closing)
            trade = await prisma.trade.update({
                where: { id: existingTrade.id },
                data: {
                    closePrice: validatedData.closePrice,
                    closeTime: validatedData.closeTime ? new Date(validatedData.closeTime) : null,
                    profit: validatedData.profit,
                    pips: validatedData.pips,
                    swap: validatedData.swap,
                    commission: validatedData.commission,
                    status: validatedData.status,
                    stopLoss: validatedData.stopLoss,
                    takeProfit: validatedData.takeProfit,
                },
            })
        } else {
            // Create new trade
            trade = await prisma.trade.create({
                data: {
                    userId: user.id,
                    mtAccountId: mtAccount.id,
                    eaId,
                    ticket: validatedData.ticket,
                    symbol: validatedData.symbol,
                    type: validatedData.type,
                    lots: validatedData.lots,
                    openPrice: validatedData.openPrice,
                    closePrice: validatedData.closePrice,
                    stopLoss: validatedData.stopLoss,
                    takeProfit: validatedData.takeProfit,
                    openTime: new Date(validatedData.openTime),
                    closeTime: validatedData.closeTime ? new Date(validatedData.closeTime) : null,
                    profit: validatedData.profit,
                    pips: validatedData.pips,
                    swap: validatedData.swap ?? 0,
                    commission: validatedData.commission ?? 0,
                    status: validatedData.status,
                },
            })
        }

        // TODO: Trigger notifications if enabled
        // await sendTradeNotification(user.id, trade, existingTrade ? 'update' : 'open')

        return NextResponse.json({
            success: true,
            message: existingTrade ? "Trade updated" : "Trade recorded",
            tradeId: trade.id,
        })
    } catch (error) {
        console.error("Trade submission error:", error)
        return NextResponse.json(
            { success: false, message: "Failed to submit trade" },
            { status: 500 }
        )
    }
}

// GET: Fetch trades for the current user (from dashboard)
export async function GET(request: NextRequest) {
    try {
        const { searchParams } = new URL(request.url)
        const userId = searchParams.get("userId")
        const status = searchParams.get("status") as "OPEN" | "CLOSED" | null
        const accountId = searchParams.get("accountId")
        const eaId = searchParams.get("eaId")
        const limit = parseInt(searchParams.get("limit") || "50")
        const offset = parseInt(searchParams.get("offset") || "0")

        if (!userId) {
            return NextResponse.json(
                { success: false, message: "User ID required" },
                { status: 400 }
            )
        }

        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const where: any = { userId }
        if (status) where.status = status
        if (accountId) where.mtAccountId = accountId
        if (eaId) where.eaId = eaId

        const [trades, total] = await Promise.all([
            prisma.trade.findMany({
                where,
                orderBy: { openTime: "desc" },
                take: limit,
                skip: offset,
                include: {
                    mtAccount: { select: { accountNumber: true, brokerName: true } },
                    ea: { select: { name: true, eaCode: true } },
                },
            }),
            prisma.trade.count({ where }),
        ])

        return NextResponse.json({
            success: true,
            trades,
            total,
            limit,
            offset,
        })
    } catch (error) {
        console.error("Fetch trades error:", error)
        return NextResponse.json(
            { success: false, message: "Failed to fetch trades" },
            { status: 500 }
        )
    }
}
