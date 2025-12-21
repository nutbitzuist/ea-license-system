import { NextRequest, NextResponse } from "next/server"
import { getServerSession } from "next-auth"
import { authOptions } from "@/lib/auth"
import { prisma } from "@/lib/db"
import { z } from "zod"

const createPromoCodeSchema = z.object({
    code: z.string().min(3).max(50).toUpperCase(),
    description: z.string().optional(),
    daysGranted: z.number().int().min(0).default(0),
    subscriptionTier: z.enum(["TIER_1", "TIER_2", "TIER_3"]).optional().nullable(),
    maxUsages: z.number().int().min(0).default(0),
    expiresAt: z.string().datetime().optional().nullable(),
})

const updatePromoCodeSchema = z.object({
    description: z.string().optional(),
    daysGranted: z.number().int().min(0).optional(),
    subscriptionTier: z.enum(["TIER_1", "TIER_2", "TIER_3"]).optional().nullable(),
    maxUsages: z.number().int().min(0).optional(),
    isActive: z.boolean().optional(),
    expiresAt: z.string().datetime().optional().nullable(),
})

// GET: List all promo codes
export async function GET() {
    try {
        const session = await getServerSession(authOptions)
        if (!session?.user?.id || session.user.role !== "ADMIN") {
            return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
        }

        const promoCodes = await prisma.promoCode.findMany({
            orderBy: { createdAt: "desc" },
            include: {
                _count: {
                    select: { usages: true },
                },
            },
        })

        return NextResponse.json({ promoCodes })
    } catch (error) {
        console.error("Get promo codes error:", error)
        return NextResponse.json({ error: "Failed to fetch promo codes" }, { status: 500 })
    }
}

// POST: Create a new promo code
export async function POST(request: NextRequest) {
    try {
        const session = await getServerSession(authOptions)
        if (!session?.user?.id || session.user.role !== "ADMIN") {
            return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
        }

        const body = await request.json()
        const data = createPromoCodeSchema.parse(body)

        // Check if code already exists
        const existing = await prisma.promoCode.findUnique({
            where: { code: data.code },
        })

        if (existing) {
            return NextResponse.json(
                { error: "A promo code with this code already exists" },
                { status: 400 }
            )
        }

        const promoCode = await prisma.promoCode.create({
            data: {
                code: data.code,
                description: data.description,
                daysGranted: data.daysGranted,
                subscriptionTier: data.subscriptionTier,
                maxUsages: data.maxUsages,
                expiresAt: data.expiresAt ? new Date(data.expiresAt) : null,
            },
        })

        return NextResponse.json({
            success: true,
            message: "Promo code created successfully",
            promoCode,
        })
    } catch (error) {
        console.error("Create promo code error:", error)

        if (error instanceof z.ZodError) {
            return NextResponse.json(
                { error: error.issues[0]?.message || "Validation failed" },
                { status: 400 }
            )
        }

        return NextResponse.json({ error: "Failed to create promo code" }, { status: 500 })
    }
}

// PATCH: Update a promo code
export async function PATCH(request: NextRequest) {
    try {
        const session = await getServerSession(authOptions)
        if (!session?.user?.id || session.user.role !== "ADMIN") {
            return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
        }

        const { searchParams } = new URL(request.url)
        const id = searchParams.get("id")

        if (!id) {
            return NextResponse.json({ error: "Promo code ID is required" }, { status: 400 })
        }

        const body = await request.json()
        const data = updatePromoCodeSchema.parse(body)

        const promoCode = await prisma.promoCode.update({
            where: { id },
            data: {
                ...(data.description !== undefined && { description: data.description }),
                ...(data.daysGranted !== undefined && { daysGranted: data.daysGranted }),
                ...(data.subscriptionTier !== undefined && { subscriptionTier: data.subscriptionTier }),
                ...(data.maxUsages !== undefined && { maxUsages: data.maxUsages }),
                ...(data.isActive !== undefined && { isActive: data.isActive }),
                ...(data.expiresAt !== undefined && { expiresAt: data.expiresAt ? new Date(data.expiresAt) : null }),
            },
        })

        return NextResponse.json({
            success: true,
            message: "Promo code updated successfully",
            promoCode,
        })
    } catch (error) {
        console.error("Update promo code error:", error)

        if (error instanceof z.ZodError) {
            return NextResponse.json(
                { error: error.issues[0]?.message || "Validation failed" },
                { status: 400 }
            )
        }

        return NextResponse.json({ error: "Failed to update promo code" }, { status: 500 })
    }
}

// DELETE: Delete a promo code
export async function DELETE(request: NextRequest) {
    try {
        const session = await getServerSession(authOptions)
        if (!session?.user?.id || session.user.role !== "ADMIN") {
            return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
        }

        const { searchParams } = new URL(request.url)
        const id = searchParams.get("id")

        if (!id) {
            return NextResponse.json({ error: "Promo code ID is required" }, { status: 400 })
        }

        await prisma.promoCode.delete({
            where: { id },
        })

        return NextResponse.json({
            success: true,
            message: "Promo code deleted successfully",
        })
    } catch (error) {
        console.error("Delete promo code error:", error)
        return NextResponse.json({ error: "Failed to delete promo code" }, { status: 500 })
    }
}
