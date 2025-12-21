"use client"

import { useSession } from "next-auth/react"
import { useQuery } from "@tanstack/react-query"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Users, Bot, Key, Activity, AlertCircle, CheckCircle } from "lucide-react"

export default function DashboardPage() {
  const { data: session } = useSession()

  const { data: stats, isLoading } = useQuery({
    queryKey: ["dashboard-stats"],
    queryFn: async () => {
      const res = await fetch("/api/dashboard/stats")
      if (!res.ok) throw new Error("Failed to fetch stats")
      return res.json()
    },
    staleTime: 30 * 1000, // Consider fresh for 30 seconds
  })


  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-3xl font-bold tracking-tight">Dashboard</h2>
        <p className="text-muted-foreground">
          Welcome back, {session?.user?.name}
        </p>
      </div>

      {/* Status Banner */}
      {session?.user && !session.user.isApproved && (
        <Card className="border-yellow-500 bg-yellow-50 dark:bg-yellow-950/20">
          <CardContent className="flex items-center gap-4 py-4">
            <AlertCircle className="h-5 w-5 text-yellow-500" />
            <div>
              <p className="font-medium text-yellow-700 dark:text-yellow-400">
                Account Pending Approval
              </p>
              <p className="text-sm text-yellow-600 dark:text-yellow-500">
                Your account is awaiting admin approval. Some features may be limited.
              </p>
            </div>
          </CardContent>
        </Card>
      )}

      {session?.user?.isApproved && (
        <Card className="border-green-500 bg-green-50 dark:bg-green-950/20">
          <CardContent className="flex items-center gap-4 py-4">
            <CheckCircle className="h-5 w-5 text-green-500" />
            <div>
              <p className="font-medium text-green-700 dark:text-green-400">
                Account Active
              </p>
              <p className="text-sm text-green-600 dark:text-green-500">
                Your account is approved and fully operational.
              </p>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Stats Grid */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">MT Accounts</CardTitle>
            <Users className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              {isLoading ? "..." : stats?.accountsUsed || 0}
            </div>
            <p className="text-xs text-muted-foreground">
              of {stats?.maxAccounts || 1} available
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Expert Advisors</CardTitle>
            <Bot className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              {isLoading ? "..." : stats?.easAccess || 0}
            </div>
            <p className="text-xs text-muted-foreground">
              EAs with access
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Validations Today</CardTitle>
            <Activity className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              {isLoading ? "..." : stats?.validationsToday || 0}
            </div>
            <p className="text-xs text-muted-foreground">
              license checks
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Subscription</CardTitle>
            <Key className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              {stats?.subscriptionTier?.replace("_", " ") || "TIER 1"}
            </div>
            <p className="text-xs text-muted-foreground">
              current plan
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Recent Activity */}
      <Card>
        <CardHeader>
          <CardTitle>Recent Validations</CardTitle>
          <CardDescription>
            Your latest license validation attempts
          </CardDescription>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <p className="text-muted-foreground">Loading...</p>
          ) : stats?.recentValidations?.length > 0 ? (
            <div className="space-y-4">
              {stats.recentValidations.map((log: {
                id: string
                eaCode: string
                accountNumber: string
                result: string
                createdAt: string
              }) => (
                <div key={log.id} className="flex items-center justify-between border-b pb-4 last:border-0">
                  <div>
                    <p className="font-medium">{log.eaCode}</p>
                    <p className="text-sm text-muted-foreground">
                      Account: {log.accountNumber}
                    </p>
                  </div>
                  <div className="text-right">
                    <Badge variant={log.result === "SUCCESS" ? "success" : "destructive"}>
                      {log.result}
                    </Badge>
                    <p className="text-xs text-muted-foreground mt-1">
                      {new Date(log.createdAt).toLocaleString()}
                    </p>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <p className="text-muted-foreground">No recent validations</p>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
