import { NextResponse } from "next/server"
import { prisma } from "@/lib/db"
import { getServerSession } from "next-auth"
import { authOptions } from "@/lib/auth"

// GET: Fetch referral stats for current user
export async function GET() {
    try {
        const session = await getServerSession(authOptions)
        if (!session?.user?.id) {
            return NextResponse.json(
                { success: false, message: "Unauthorized" },
                { status: 401 }
            )
        }

        const userId = session.user.id

        // Get user's referral code
        const user = await prisma.user.findUnique({
            where: { id: userId },
            select: { referralCode: true, referredByCode: true },
        })

        if (!user) {
            return NextResponse.json(
                { success: false, message: "User not found" },
                { status: 404 }
            )
        }

        // Get referrals made by this user
        const referrals = await prisma.referral.findMany({
            where: { referrerId: userId },
            orderBy: { createdAt: "desc" },
            include: {
                referred: {
                    select: {
                        name: true,
                        createdAt: true,
                        isApproved: true,
                    },
                },
            },
        })

        // Calculate stats
        const totalReferrals = referrals.length
        const approvedReferrals = referrals.filter(r => r.status === "APPROVED" || r.status === "REWARDED").length
        const pendingReferrals = referrals.filter(r => r.status === "PENDING").length
        const rewardsEarned = referrals.filter(r => r.rewardGiven).length

        // Anonymize referred user names (show only first letter + asterisks)
        const referralList = referrals.map(r => ({
            id: r.id,
            referredName: r.referred.name.charAt(0) + "***",
            status: r.status,
            rewardGiven: r.rewardGiven,
            joinedAt: r.referred.createdAt,
            isApproved: r.referred.isApproved,
        }))

        return NextResponse.json({
            success: true,
            referralCode: user.referralCode,
            wasReferred: !!user.referredByCode,
            stats: {
                totalReferrals,
                approvedReferrals,
                pendingReferrals,
                rewardsEarned,
            },
            referrals: referralList,
        })
    } catch (error) {
        console.error("Referral stats error:", error)
        return NextResponse.json(
            { success: false, message: "Failed to fetch referral stats" },
            { status: 500 }
        )
    }
}
