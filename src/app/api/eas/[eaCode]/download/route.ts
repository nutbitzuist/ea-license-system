import { NextRequest, NextResponse } from "next/server"
import { auth } from "@/lib/auth"
import { prisma } from "@/lib/db"

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ eaCode: string }> }
) {
  try {
    const session = await auth()
    if (!session?.user?.id) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
    }

    const { eaCode } = await params
    const terminal = request.nextUrl.searchParams.get("terminal") as "MT4" | "MT5"

    if (!terminal || !["MT4", "MT5"].includes(terminal)) {
      return NextResponse.json({ error: "Invalid terminal type" }, { status: 400 })
    }

    // Find EA
    const ea = await prisma.expertAdvisor.findUnique({
      where: { eaCode },
    })

    if (!ea || !ea.isActive) {
      return NextResponse.json({ error: "EA not found" }, { status: 404 })
    }

    // Check user access
    const access = await prisma.userEaAccess.findFirst({
      where: {
        userId: session.user.id,
        eaId: ea.id,
        isEnabled: true,
        OR: [
          { expiresAt: null },
          { expiresAt: { gt: new Date() } },
        ],
      },
    })

    if (!access) {
      return NextResponse.json({ error: "Access denied" }, { status: 403 })
    }

    const fileName = terminal === "MT4" ? ea.mt4FileName : ea.mt5FileName

    if (!fileName) {
      return NextResponse.json(
        { error: `No ${terminal} file available for this EA` },
        { status: 404 }
      )
    }

    // In a real implementation, you would fetch the file from Supabase Storage
    // For now, return a placeholder response
    return NextResponse.json({
      message: "Download would be initiated here",
      fileName,
      downloadUrl: `/storage/${fileName}`,
    })
  } catch (error) {
    console.error("Download EA error:", error)
    return NextResponse.json({ error: "Download failed" }, { status: 500 })
  }
}
