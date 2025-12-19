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

    // Get EAs the user has access to
    const userEaAccess = await prisma.userEaAccess.findMany({
      where: {
        userId: session.user.id,
        isEnabled: true,
        OR: [
          { expiresAt: null },
          { expiresAt: { gt: new Date() } },
        ],
      },
      include: {
        ea: true,
      },
    })

    const eas = userEaAccess
      .filter((access: { ea: { isActive: boolean } }) => access.ea.isActive)
      .map((access: { ea: Record<string, unknown>; expiresAt: Date | null }) => ({
        ...access.ea,
        expiresAt: access.expiresAt,
      }))

    return NextResponse.json({ eas })
  } catch (error) {
    console.error("Get EAs error:", error)
    return NextResponse.json({ error: "Failed to fetch EAs" }, { status: 500 })
  }
}
