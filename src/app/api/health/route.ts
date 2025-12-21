import { NextResponse } from "next/server"
import { prisma } from "@/lib/db"

export const dynamic = "force-dynamic"

export async function GET() {
    const startTime = Date.now()

    try {
        // Check database connectivity
        await prisma.$queryRaw`SELECT 1`

        const responseTime = Date.now() - startTime

        return NextResponse.json({
            status: "healthy",
            timestamp: new Date().toISOString(),
            checks: {
                database: "connected",
                responseTime: `${responseTime}ms`,
            },
        })
    } catch (error) {
        const responseTime = Date.now() - startTime

        console.error("Health check failed:", error)

        return NextResponse.json(
            {
                status: "unhealthy",
                timestamp: new Date().toISOString(),
                checks: {
                    database: "disconnected",
                    responseTime: `${responseTime}ms`,
                },
                error: "Database connection failed",
            },
            { status: 503 }
        )
    }
}
