"use client"

import { useState } from "react"
import { useQuery } from "@tanstack/react-query"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Input } from "@/components/ui/input"
import { useToast } from "@/hooks/use-toast"
import {
    Gift,
    Users,
    CheckCircle2,
    Clock,
    Copy,
    Share2,
    Loader2,
    Award,
} from "lucide-react"

interface ReferralStats {
    totalReferrals: number
    approvedReferrals: number
    pendingReferrals: number
    rewardsEarned: number
}

interface ReferralItem {
    id: string
    referredName: string
    status: "PENDING" | "APPROVED" | "REWARDED"
    rewardGiven: boolean
    joinedAt: string
    isApproved: boolean
}

interface ReferralResponse {
    success: boolean
    referralCode: string
    wasReferred: boolean
    stats: ReferralStats
    referrals: ReferralItem[]
}

export default function ReferralsPage() {
    const { toast } = useToast()
    const [copied, setCopied] = useState(false)

    const { data, isLoading } = useQuery<ReferralResponse>({
        queryKey: ["referrals"],
        queryFn: async () => {
            const res = await fetch("/api/referrals")
            if (!res.ok) throw new Error("Failed to fetch referrals")
            return res.json()
        },
    })

    const referralLink = typeof window !== "undefined"
        ? `${window.location.origin}/register?ref=${data?.referralCode}`
        : ""

    const copyToClipboard = async () => {
        try {
            await navigator.clipboard.writeText(referralLink)
            setCopied(true)
            toast({ title: "Copied!", description: "Referral link copied to clipboard" })
            setTimeout(() => setCopied(false), 2000)
        } catch {
            toast({ title: "Error", description: "Failed to copy", variant: "destructive" })
        }
    }

    const shareLink = async () => {
        if (navigator.share) {
            try {
                await navigator.share({
                    title: "Join My Algo Stack",
                    text: "Get access to 40+ premium trading EAs with a 14-day free trial!",
                    url: referralLink,
                })
            } catch {
                // User cancelled
            }
        } else {
            copyToClipboard()
        }
    }

    if (isLoading) {
        return (
            <div className="flex items-center justify-center py-12">
                <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
            </div>
        )
    }

    return (
        <div className="space-y-6">
            <div>
                <h2 className="text-3xl font-bold tracking-tight">Referral Program</h2>
                <p className="text-muted-foreground">
                    Invite friends and earn rewards when they subscribe
                </p>
            </div>

            {/* Referral Link Card */}
            <Card className="border-primary/20 bg-gradient-to-br from-primary/5 to-primary/10">
                <CardHeader>
                    <CardTitle className="flex items-center gap-2">
                        <Gift className="h-5 w-5 text-primary" />
                        Your Referral Link
                    </CardTitle>
                    <CardDescription>
                        Share this link with friends. When they sign up and subscribe, you both earn rewards!
                    </CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                    <div className="flex gap-2">
                        <Input
                            value={referralLink}
                            readOnly
                            className="font-mono text-sm bg-background"
                        />
                        <Button
                            variant="outline"
                            size="icon"
                            onClick={copyToClipboard}
                            className={copied ? "text-green-500" : ""}
                        >
                            {copied ? <CheckCircle2 className="h-4 w-4" /> : <Copy className="h-4 w-4" />}
                        </Button>
                        <Button onClick={shareLink}>
                            <Share2 className="h-4 w-4 mr-2" />
                            Share
                        </Button>
                    </div>
                    <p className="text-sm text-muted-foreground">
                        Your referral code: <code className="bg-muted px-2 py-1 rounded font-mono">{data?.referralCode}</code>
                    </p>
                </CardContent>
            </Card>

            {/* Stats Grid */}
            <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
                <Card>
                    <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                        <CardTitle className="text-sm font-medium">Total Referrals</CardTitle>
                        <Users className="h-4 w-4 text-muted-foreground" />
                    </CardHeader>
                    <CardContent>
                        <div className="text-2xl font-bold">{data?.stats.totalReferrals ?? 0}</div>
                        <p className="text-xs text-muted-foreground">People you&apos;ve invited</p>
                    </CardContent>
                </Card>

                <Card>
                    <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                        <CardTitle className="text-sm font-medium">Approved</CardTitle>
                        <CheckCircle2 className="h-4 w-4 text-green-500" />
                    </CardHeader>
                    <CardContent>
                        <div className="text-2xl font-bold text-green-500">
                            {data?.stats.approvedReferrals ?? 0}
                        </div>
                        <p className="text-xs text-muted-foreground">Active subscribers</p>
                    </CardContent>
                </Card>

                <Card>
                    <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                        <CardTitle className="text-sm font-medium">Pending</CardTitle>
                        <Clock className="h-4 w-4 text-yellow-500" />
                    </CardHeader>
                    <CardContent>
                        <div className="text-2xl font-bold text-yellow-500">
                            {data?.stats.pendingReferrals ?? 0}
                        </div>
                        <p className="text-xs text-muted-foreground">Awaiting subscription</p>
                    </CardContent>
                </Card>

                <Card>
                    <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                        <CardTitle className="text-sm font-medium">Rewards Earned</CardTitle>
                        <Award className="h-4 w-4 text-primary" />
                    </CardHeader>
                    <CardContent>
                        <div className="text-2xl font-bold text-primary">
                            {data?.stats.rewardsEarned ?? 0}
                        </div>
                        <p className="text-xs text-muted-foreground">Total rewards claimed</p>
                    </CardContent>
                </Card>
            </div>

            {/* Referral List */}
            <Card>
                <CardHeader>
                    <CardTitle className="flex items-center gap-2">
                        <Users className="h-5 w-5" />
                        Your Referrals
                    </CardTitle>
                    <CardDescription>People who signed up using your referral link</CardDescription>
                </CardHeader>
                <CardContent>
                    {data?.referrals && data.referrals.length > 0 ? (
                        <div className="space-y-3">
                            {data.referrals.map((referral) => (
                                <div
                                    key={referral.id}
                                    className="flex items-center justify-between p-3 rounded-lg bg-muted/50"
                                >
                                    <div className="flex items-center gap-3">
                                        <div className="h-10 w-10 rounded-full bg-primary/10 flex items-center justify-center">
                                            <span className="text-lg font-bold text-primary">
                                                {referral.referredName.charAt(0).toUpperCase()}
                                            </span>
                                        </div>
                                        <div>
                                            <div className="font-medium">{referral.referredName}</div>
                                            <div className="text-sm text-muted-foreground">
                                                Joined {new Date(referral.joinedAt).toLocaleDateString()}
                                            </div>
                                        </div>
                                    </div>
                                    <div className="flex items-center gap-2">
                                        <Badge
                                            variant={
                                                referral.status === "REWARDED" ? "default" :
                                                    referral.status === "APPROVED" ? "secondary" : "outline"
                                            }
                                        >
                                            {referral.status === "REWARDED" && <Award className="h-3 w-3 mr-1" />}
                                            {referral.status === "APPROVED" && <CheckCircle2 className="h-3 w-3 mr-1" />}
                                            {referral.status === "PENDING" && <Clock className="h-3 w-3 mr-1" />}
                                            {referral.status}
                                        </Badge>
                                    </div>
                                </div>
                            ))}
                        </div>
                    ) : (
                        <div className="text-center py-8 text-muted-foreground">
                            <Gift className="h-12 w-12 mx-auto mb-4 opacity-50" />
                            <p>No referrals yet</p>
                            <p className="text-sm">Share your referral link to start earning rewards!</p>
                        </div>
                    )}
                </CardContent>
            </Card>

            {/* How it Works */}
            <Card>
                <CardHeader>
                    <CardTitle>How It Works</CardTitle>
                </CardHeader>
                <CardContent>
                    <div className="grid gap-4 md:grid-cols-3">
                        <div className="text-center p-4">
                            <div className="h-12 w-12 rounded-full bg-primary/10 flex items-center justify-center mx-auto mb-3">
                                <Share2 className="h-6 w-6 text-primary" />
                            </div>
                            <h3 className="font-medium mb-1">1. Share Your Link</h3>
                            <p className="text-sm text-muted-foreground">
                                Send your unique referral link to friends
                            </p>
                        </div>
                        <div className="text-center p-4">
                            <div className="h-12 w-12 rounded-full bg-primary/10 flex items-center justify-center mx-auto mb-3">
                                <Users className="h-6 w-6 text-primary" />
                            </div>
                            <h3 className="font-medium mb-1">2. They Sign Up</h3>
                            <p className="text-sm text-muted-foreground">
                                Your friend creates an account and subscribes
                            </p>
                        </div>
                        <div className="text-center p-4">
                            <div className="h-12 w-12 rounded-full bg-primary/10 flex items-center justify-center mx-auto mb-3">
                                <Award className="h-6 w-6 text-primary" />
                            </div>
                            <h3 className="font-medium mb-1">3. Both Earn Rewards</h3>
                            <p className="text-sm text-muted-foreground">
                                You both get rewards when they become active
                            </p>
                        </div>
                    </div>
                </CardContent>
            </Card>
        </div>
    )
}
