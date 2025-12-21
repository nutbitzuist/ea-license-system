import { NextRequest, NextResponse } from "next/server"
import { getServerSession } from "next-auth"
import { authOptions } from "@/lib/auth"
import { prisma } from "@/lib/db"

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const session = await getServerSession(authOptions)
    if (!session?.user?.id || session.user.role !== "ADMIN") {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
    }

    const { id } = await params

    const user = await prisma.user.findUnique({
      where: { id },
      select: {
        id: true,
        email: true,
        name: true,
        role: true,
        subscriptionTier: true,
        isActive: true,
        isApproved: true,
        createdAt: true,
        mtAccounts: {
          select: {
            id: true,
            accountNumber: true,
            brokerName: true,
            accountType: true,
            terminalType: true,
            isActive: true,
          },
        },
        eaAccess: {
          include: {
            ea: {
              select: {
                id: true,
                name: true,
                eaCode: true,
              },
            },
          },
        },
      },
    })

    if (!user) {
      return NextResponse.json({ error: "User not found" }, { status: 404 })
    }

    return NextResponse.json({ user })
  } catch (error) {
    console.error("Get user error:", error)
    return NextResponse.json({ error: "Failed to fetch user" }, { status: 500 })
  }
}

export async function PATCH(
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

    // Check if we're approving a user (for referral reward)
    const wasApproving = body.isApproved === true
    let referralRewardGranted = false

    // First, get the current user state
    const existingUser = await prisma.user.findUnique({
      where: { id },
      select: { isApproved: true, referredByCode: true },
    })

    const user = await prisma.user.update({
      where: { id },
      data: {
        isApproved: body.isApproved,
        isActive: body.isActive,
        subscriptionTier: body.subscriptionTier,
        role: body.role,
      },
      select: {
        id: true,
        email: true,
        name: true,
        role: true,
        subscriptionTier: true,
        isActive: true,
        isApproved: true,
      },
    })

    // If user was just approved and has a referrer, grant reward
    if (wasApproving && !existingUser?.isApproved && existingUser?.referredByCode) {
      const referrer = await prisma.user.findUnique({
        where: { referralCode: existingUser.referredByCode },
        select: { id: true, trialEndsAt: true },
      })

      if (referrer) {
        const REFERRAL_REWARD_DAYS = 7 // Configurable reward days

        // Extend referrer's trial
        const currentTrialEnd = referrer.trialEndsAt || new Date()
        const newTrialEnd = new Date(currentTrialEnd)
        newTrialEnd.setDate(newTrialEnd.getDate() + REFERRAL_REWARD_DAYS)

        await prisma.user.update({
          where: { id: referrer.id },
          data: { trialEndsAt: newTrialEnd },
        })

        // Update referral record status
        await prisma.referral.updateMany({
          where: {
            referredId: id,
            referrerId: referrer.id,
          },
          data: {
            status: "REWARDED",
            rewardGiven: true,
          },
        })

        referralRewardGranted = true
      }
    }

    return NextResponse.json({
      user,
      referralRewardGranted,
    })
  } catch (error) {
    console.error("Update user error:", error)
    return NextResponse.json({ error: "Failed to update user" }, { status: 500 })
  }
}

export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const session = await getServerSession(authOptions)
    if (!session?.user?.id || session.user.role !== "ADMIN") {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
    }

    const { id } = await params

    // Prevent self-deletion
    if (id === session.user.id) {
      return NextResponse.json(
        { error: "You cannot delete your own account" },
        { status: 400 }
      )
    }

    // Check if user exists
    const user = await prisma.user.findUnique({
      where: { id },
      select: { id: true, email: true, role: true },
    })

    if (!user) {
      return NextResponse.json({ error: "User not found" }, { status: 404 })
    }

    // Prevent deleting other admins (safety measure)
    if (user.role === "ADMIN") {
      return NextResponse.json(
        { error: "Cannot delete admin accounts" },
        { status: 400 }
      )
    }

    // Delete user (cascade will handle related records)
    await prisma.user.delete({
      where: { id },
    })

    return NextResponse.json({
      success: true,
      message: `User ${user.email} has been deleted`
    })
  } catch (error) {
    console.error("Delete user error:", error)
    return NextResponse.json({ error: "Failed to delete user" }, { status: 500 })
  }
}
