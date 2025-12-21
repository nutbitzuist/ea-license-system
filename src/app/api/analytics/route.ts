import { NextResponse } from "next/server"
import { getServerSession } from "next-auth"
import { authOptions } from "@/lib/auth"
import { prisma } from "@/lib/db"

export async function GET() {
  try {
    const session = await getServerSession(authOptions)
    if (!session?.user?.id) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
    }

    // Get validation logs for this user (limit for performance)
    const logs = await prisma.validationLog.findMany({
      where: { userId: session.user.id },
      orderBy: { createdAt: "desc" },
      take: 1000, // Limit to recent activity for performance
    })


    // Calculate statistics
    const totalValidations = logs.length
    const successfulValidations = logs.filter(l => l.result === "SUCCESS").length
    const failedValidations = logs.filter(l => l.result === "FAILED").length

    // Get unique accounts
    const uniqueAccounts = new Set(logs.map(l => l.accountNumber)).size

    // Get recent logs (last 10)
    const recentLogs = logs.slice(0, 10).map(log => ({
      id: log.id,
      eaCode: log.eaCode,
      accountNumber: log.accountNumber,
      brokerName: log.brokerName,
      isValid: log.result === "SUCCESS",
      message: log.failureReason || (log.result === "SUCCESS" ? "License valid" : "License invalid"),
      createdAt: log.createdAt.toISOString(),
    }))

    // Calculate EA usage
    const eaUsageMap = new Map<string, { count: number; success: number }>()
    logs.forEach(log => {
      const current = eaUsageMap.get(log.eaCode) || { count: 0, success: 0 }
      current.count++
      if (log.result === "SUCCESS") current.success++
      eaUsageMap.set(log.eaCode, current)
    })

    const eaUsage = Array.from(eaUsageMap.entries())
      .map(([eaCode, stats]) => ({
        eaCode,
        count: stats.count,
        successRate: (stats.success / stats.count) * 100,
      }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 10)

    // Calculate daily stats (last 7 days)
    const dailyStatsMap = new Map<string, { success: number; failed: number }>()
    const now = new Date()
    for (let i = 6; i >= 0; i--) {
      const date = new Date(now)
      date.setDate(date.getDate() - i)
      const dateStr = date.toISOString().split('T')[0]
      dailyStatsMap.set(dateStr, { success: 0, failed: 0 })
    }

    logs.forEach(log => {
      const dateStr = log.createdAt.toISOString().split('T')[0]
      if (dailyStatsMap.has(dateStr)) {
        const stats = dailyStatsMap.get(dateStr)!
        if (log.result === "SUCCESS") stats.success++
        else stats.failed++
      }
    })

    const dailyStats = Array.from(dailyStatsMap.entries()).map(([date, stats]) => ({
      date,
      success: stats.success,
      failed: stats.failed,
    }))

    return NextResponse.json({
      totalValidations,
      successfulValidations,
      failedValidations,
      uniqueAccounts,
      recentLogs,
      eaUsage,
      dailyStats,
    })
  } catch (error) {
    console.error("Analytics error:", error)
    return NextResponse.json({ error: "Failed to fetch analytics" }, { status: 500 })
  }
}
