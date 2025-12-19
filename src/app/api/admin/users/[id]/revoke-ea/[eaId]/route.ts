import { NextRequest, NextResponse } from "next/server"
import { getServerSession } from "next-auth"
import { authOptions } from "@/lib/auth"
import { prisma } from "@/lib/db"

export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string; eaId: string }> }
) {
  try {
    const session = await getServerSession(authOptions)
    if (!session?.user?.id || session.user.role !== "ADMIN") {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
    }

    const { id, eaId } = await params

    await prisma.userEaAccess.deleteMany({
      where: { userId: id, eaId },
    })

    return NextResponse.json({ success: true })
  } catch (error) {
    console.error("Revoke EA access error:", error)
    return NextResponse.json({ error: "Failed to revoke EA access" }, { status: 500 })
  }
}
