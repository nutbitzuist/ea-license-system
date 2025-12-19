import { NextRequest, NextResponse } from "next/server"
import { getServerSession } from "next-auth"
import { authOptions } from "@/lib/auth"
import { prisma } from "@/lib/db"

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const session = await getServerSession(authOptions)
    if (!session?.user?.id || session.user.role !== "ADMIN") {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
    }

    const { id } = await params
    const body = await request.json()
    const { eaId, expiresAt } = body

    if (!eaId) {
      return NextResponse.json({ error: "EA ID is required" }, { status: 400 })
    }

    // Check if access already exists
    const existingAccess = await prisma.userEaAccess.findFirst({
      where: { userId: id, eaId },
    })

    if (existingAccess) {
      // Update existing access
      const access = await prisma.userEaAccess.update({
        where: { id: existingAccess.id },
        data: {
          isEnabled: true,
          expiresAt: expiresAt ? new Date(expiresAt) : null,
        },
      })
      return NextResponse.json({ access })
    }

    // Create new access
    const access = await prisma.userEaAccess.create({
      data: {
        userId: id,
        eaId,
        expiresAt: expiresAt ? new Date(expiresAt) : null,
      },
    })

    return NextResponse.json({ access })
  } catch (error) {
    console.error("Grant EA access error:", error)
    return NextResponse.json({ error: "Failed to grant EA access" }, { status: 500 })
  }
}
