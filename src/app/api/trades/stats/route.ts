import { NextRequest, NextResponse } from "next/server"
import { prisma } from "@/lib/db"
import { getServerSession } from "next-auth"
import { authOptions } from "@/lib/auth"

export async function GET(request: NextRequest) {
    try {
        const session = await getServerSession(authOptions)
        if (!session?.user?.id) {
            return NextResponse.json(
                { success: false, message: "Unauthorized" },
                { status: 401 }
            )
        }

        const userId = session.user.id
        const { searchParams } = new URL(request.url)
        const accountId = searchParams.get("accountId")
        const eaId = searchParams.get("eaId")
        const period = searchParams.get("period") || "all" // all, 7d, 30d, 90d

        // Build date filter
        let dateFilter: Date | undefined
        if (period !== "all") {
            const days = parseInt(period.replace("d", ""))
            dateFilter = new Date()
            dateFilter.setDate(dateFilter.getDate() - days)
        }

        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const where: any = {
            userId,
            status: "CLOSED",
        }
        if (accountId) where.mtAccountId = accountId
        if (eaId) where.eaId = eaId
        if (dateFilter) where.closeTime = { gte: dateFilter }

        // Get closed trades for calculations (limited for performance)
        const trades = await prisma.trade.findMany({
            where,
            orderBy: { closeTime: "desc" },
            take: 5000, // Limit to recent trades for performance
            select: {
                profit: true,
                pips: true,
                swap: true,
                commission: true,
                closeTime: true,
                lots: true,
                type: true,
            },
        })


        if (trades.length === 0) {
            return NextResponse.json({
                success: true,
                stats: {
                    totalTrades: 0,
                    winningTrades: 0,
                    losingTrades: 0,
                    winRate: 0,
                    grossProfit: 0,
                    grossLoss: 0,
                    netProfit: 0,
                    profitFactor: 0,
                    averageWin: 0,
                    averageLoss: 0,
                    averagePips: 0,
                    maxDrawdown: 0,
                    totalPips: 0,
                    expectancy: 0,
                },
                equityCurve: [],
                dailyPL: [],
            })
        }

        // Calculate statistics
        let grossProfit = 0
        let grossLoss = 0
        let winningTrades = 0
        let losingTrades = 0
        let totalPips = 0
        let runningBalance = 0
        let peakBalance = 0
        let maxDrawdown = 0

        const equityCurve: { date: string; equity: number }[] = []
        const dailyPLMap = new Map<string, number>()

        trades.forEach((trade) => {
            const profit = (trade.profit ?? 0) + (trade.swap ?? 0) + (trade.commission ?? 0)
            runningBalance += profit
            totalPips += trade.pips ?? 0

            if (profit > 0) {
                grossProfit += profit
                winningTrades++
            } else {
                grossLoss += Math.abs(profit)
                losingTrades++
            }

            // Track peak and drawdown
            if (runningBalance > peakBalance) {
                peakBalance = runningBalance
            }
            const currentDrawdown = peakBalance - runningBalance
            if (currentDrawdown > maxDrawdown) {
                maxDrawdown = currentDrawdown
            }

            // Equity curve
            if (trade.closeTime) {
                equityCurve.push({
                    date: trade.closeTime.toISOString(),
                    equity: runningBalance,
                })

                // Daily P/L
                const dateKey = trade.closeTime.toISOString().split("T")[0]
                dailyPLMap.set(dateKey, (dailyPLMap.get(dateKey) ?? 0) + profit)
            }
        })

        const totalTrades = trades.length
        const netProfit = grossProfit - grossLoss
        const winRate = totalTrades > 0 ? (winningTrades / totalTrades) * 100 : 0
        const profitFactor = grossLoss > 0 ? grossProfit / grossLoss : grossProfit > 0 ? 999 : 0
        const averageWin = winningTrades > 0 ? grossProfit / winningTrades : 0
        const averageLoss = losingTrades > 0 ? grossLoss / losingTrades : 0
        const averagePips = totalTrades > 0 ? totalPips / totalTrades : 0
        const expectancy = totalTrades > 0 ? netProfit / totalTrades : 0

        // Convert daily P/L map to array
        const dailyPL = Array.from(dailyPLMap.entries())
            .map(([date, pl]) => ({ date, pl }))
            .sort((a, b) => a.date.localeCompare(b.date))

        // Get per-EA breakdown
        const eaStats = await prisma.trade.groupBy({
            by: ["eaId"],
            where: { userId, status: "CLOSED" },
            _count: { id: true },
            _sum: { profit: true, pips: true },
        })

        const eaBreakdown = await Promise.all(
            eaStats
                .filter((s) => s.eaId)
                .map(async (s) => {
                    const ea = await prisma.expertAdvisor.findUnique({
                        where: { id: s.eaId! },
                        select: { name: true, eaCode: true },
                    })
                    return {
                        eaId: s.eaId,
                        eaName: ea?.name ?? "Unknown",
                        eaCode: ea?.eaCode ?? "unknown",
                        trades: s._count.id,
                        profit: s._sum.profit ?? 0,
                        pips: s._sum.pips ?? 0,
                    }
                })
        )

        return NextResponse.json({
            success: true,
            stats: {
                totalTrades,
                winningTrades,
                losingTrades,
                winRate: Math.round(winRate * 100) / 100,
                grossProfit: Math.round(grossProfit * 100) / 100,
                grossLoss: Math.round(grossLoss * 100) / 100,
                netProfit: Math.round(netProfit * 100) / 100,
                profitFactor: Math.round(profitFactor * 100) / 100,
                averageWin: Math.round(averageWin * 100) / 100,
                averageLoss: Math.round(averageLoss * 100) / 100,
                averagePips: Math.round(averagePips * 10) / 10,
                maxDrawdown: Math.round(maxDrawdown * 100) / 100,
                totalPips: Math.round(totalPips * 10) / 10,
                expectancy: Math.round(expectancy * 100) / 100,
            },
            equityCurve: equityCurve.slice(-100), // Last 100 data points
            dailyPL: dailyPL.slice(-30), // Last 30 days
            eaBreakdown,
        })
    } catch (error) {
        console.error("Stats error:", error)
        return NextResponse.json(
            { success: false, message: "Failed to fetch stats" },
            { status: 500 }
        )
    }
}
