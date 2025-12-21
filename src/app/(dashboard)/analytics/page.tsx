"use client"

import { useQuery } from "@tanstack/react-query"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import {
  BarChart3,
  CheckCircle2,
  XCircle,
  Clock,
  Bot,
  Loader2,
  TrendingUp,
  Activity,
} from "lucide-react"

interface ValidationLog {
  id: string
  eaCode: string
  accountNumber: string
  brokerName: string | null
  isValid: boolean
  message: string
  createdAt: string
}

interface AnalyticsData {
  totalValidations: number
  successfulValidations: number
  failedValidations: number
  uniqueAccounts: number
  recentLogs: ValidationLog[]
  eaUsage: { eaCode: string; count: number; successRate: number }[]
  dailyStats: { date: string; success: number; failed: number }[]
}

export default function AnalyticsPage() {
  const { data, isLoading } = useQuery<AnalyticsData>({
    queryKey: ["user-analytics"],
    queryFn: async () => {
      const res = await fetch("/api/analytics")
      if (!res.ok) throw new Error("Failed to fetch analytics")
      return res.json()
    },
    staleTime: 60 * 1000, // Consider fresh for 60 seconds
  })

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-12">
        <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
      </div>
    )
  }

  const successRate = data?.totalValidations
    ? ((data.successfulValidations / data.totalValidations) * 100).toFixed(1)
    : "0"

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-3xl font-bold tracking-tight">License Usage</h2>
        <p className="text-muted-foreground">
          Monitor your EA license usage and validation statistics
        </p>
      </div>

      {/* Stats Cards */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Validations</CardTitle>
            <Activity className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{data?.totalValidations || 0}</div>
            <p className="text-xs text-muted-foreground">All time license checks</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Success Rate</CardTitle>
            <TrendingUp className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-green-500">{successRate}%</div>
            <p className="text-xs text-muted-foreground">
              {data?.successfulValidations || 0} successful validations
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Failed Validations</CardTitle>
            <XCircle className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-red-500">{data?.failedValidations || 0}</div>
            <p className="text-xs text-muted-foreground">License check failures</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Unique Accounts</CardTitle>
            <Bot className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{data?.uniqueAccounts || 0}</div>
            <p className="text-xs text-muted-foreground">MT accounts used</p>
          </CardContent>
        </Card>
      </div>

      {/* EA Usage */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <BarChart3 className="h-5 w-5" />
            EA Usage Statistics
          </CardTitle>
          <CardDescription>Validation counts per Expert Advisor</CardDescription>
        </CardHeader>
        <CardContent>
          {data?.eaUsage && data.eaUsage.length > 0 ? (
            <div className="space-y-4">
              {data.eaUsage.map((ea) => (
                <div key={ea.eaCode} className="flex items-center gap-4">
                  <div className="w-48 truncate font-medium">{ea.eaCode}</div>
                  <div className="flex-1">
                    <div className="h-2 rounded-full bg-muted overflow-hidden">
                      <div
                        className="h-full bg-primary transition-all"
                        style={{
                          width: `${(ea.count / Math.max(...data.eaUsage.map(e => e.count))) * 100}%`
                        }}
                      />
                    </div>
                  </div>
                  <div className="w-16 text-right text-sm text-muted-foreground">
                    {ea.count} calls
                  </div>
                  <Badge variant={ea.successRate >= 90 ? "default" : ea.successRate >= 70 ? "secondary" : "destructive"}>
                    {ea.successRate.toFixed(0)}%
                  </Badge>
                </div>
              ))}
            </div>
          ) : (
            <div className="text-center py-8 text-muted-foreground">
              <BarChart3 className="h-12 w-12 mx-auto mb-4 opacity-50" />
              <p>No usage data yet</p>
              <p className="text-sm">Start using your EAs to see statistics here</p>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Recent Validations */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Clock className="h-5 w-5" />
            Recent Validations
          </CardTitle>
          <CardDescription>Latest license validation attempts</CardDescription>
        </CardHeader>
        <CardContent>
          {data?.recentLogs && data.recentLogs.length > 0 ? (
            <div className="space-y-3">
              {data.recentLogs.map((log) => (
                <div
                  key={log.id}
                  className="flex items-center justify-between p-3 rounded-lg bg-muted/50"
                >
                  <div className="flex items-center gap-3">
                    {log.isValid ? (
                      <CheckCircle2 className="h-5 w-5 text-green-500" />
                    ) : (
                      <XCircle className="h-5 w-5 text-red-500" />
                    )}
                    <div>
                      <div className="font-medium">{log.eaCode}</div>
                      <div className="text-sm text-muted-foreground">
                        Account: {log.accountNumber} {log.brokerName && `• ${log.brokerName}`}
                      </div>
                    </div>
                  </div>
                  <div className="text-right">
                    <Badge variant={log.isValid ? "default" : "destructive"}>
                      {log.isValid ? "Valid" : "Invalid"}
                    </Badge>
                    <div className="text-xs text-muted-foreground mt-1">
                      {new Date(log.createdAt).toLocaleString()}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="text-center py-8 text-muted-foreground">
              <Clock className="h-12 w-12 mx-auto mb-4 opacity-50" />
              <p>No validation logs yet</p>
              <p className="text-sm">Logs will appear when your EAs validate their licenses</p>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
