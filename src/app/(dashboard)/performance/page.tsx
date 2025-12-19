"use client"

import { useQuery } from "@tanstack/react-query"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import {
    TrendingUp,
    TrendingDown,
    Target,
    BarChart3,
    Loader2,
    DollarSign,
    Percent,
    Activity,
    ArrowUpRight,
    ArrowDownRight,
} from "lucide-react"

interface TradeStats {
    totalTrades: number
    winningTrades: number
    losingTrades: number
    winRate: number
    grossProfit: number
    grossLoss: number
    netProfit: number
    profitFactor: number
    averageWin: number
    averageLoss: number
    averagePips: number
    maxDrawdown: number
    totalPips: number
    expectancy: number
}

interface EABreakdown {
    eaId: string
    eaName: string
    eaCode: string
    trades: number
    profit: number
    pips: number
}

interface DailyPL {
    date: string
    pl: number
}

interface StatsResponse {
    success: boolean
    stats: TradeStats
    equityCurve: { date: string; equity: number }[]
    dailyPL: DailyPL[]
    eaBreakdown: EABreakdown[]
}

export default function PerformancePage() {
    const { data, isLoading } = useQuery<StatsResponse>({
        queryKey: ["trade-stats"],
        queryFn: async () => {
            const res = await fetch("/api/trades/stats")
            if (!res.ok) throw new Error("Failed to fetch stats")
            return res.json()
        },
    })

    if (isLoading) {
        return (
            <div className="flex items-center justify-center py-12">
                <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
            </div>
        )
    }

    const stats = data?.stats

    return (
        <div className="space-y-6">
            <div>
                <h2 className="text-3xl font-bold tracking-tight">Trade Performance</h2>
                <p className="text-muted-foreground">
                    Track your trading performance across all accounts and EAs
                </p>
            </div>

            {/* Key Metrics */}
            <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
                <Card>
                    <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                        <CardTitle className="text-sm font-medium">Net Profit</CardTitle>
                        <DollarSign className="h-4 w-4 text-muted-foreground" />
                    </CardHeader>
                    <CardContent>
                        <div className={`text-2xl font-bold ${(stats?.netProfit ?? 0) >= 0 ? 'text-green-500' : 'text-red-500'}`}>
                            ${stats?.netProfit?.toFixed(2) ?? "0.00"}
                        </div>
                        <p className="text-xs text-muted-foreground">
                            Total closed trades: {stats?.totalTrades ?? 0}
                        </p>
                    </CardContent>
                </Card>

                <Card>
                    <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                        <CardTitle className="text-sm font-medium">Win Rate</CardTitle>
                        <Percent className="h-4 w-4 text-muted-foreground" />
                    </CardHeader>
                    <CardContent>
                        <div className={`text-2xl font-bold ${(stats?.winRate ?? 0) >= 50 ? 'text-green-500' : 'text-yellow-500'}`}>
                            {stats?.winRate?.toFixed(1) ?? "0"}%
                        </div>
                        <p className="text-xs text-muted-foreground">
                            {stats?.winningTrades ?? 0}W / {stats?.losingTrades ?? 0}L
                        </p>
                    </CardContent>
                </Card>

                <Card>
                    <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                        <CardTitle className="text-sm font-medium">Profit Factor</CardTitle>
                        <Target className="h-4 w-4 text-muted-foreground" />
                    </CardHeader>
                    <CardContent>
                        <div className={`text-2xl font-bold ${(stats?.profitFactor ?? 0) >= 1.5 ? 'text-green-500' : (stats?.profitFactor ?? 0) >= 1 ? 'text-yellow-500' : 'text-red-500'}`}>
                            {stats?.profitFactor?.toFixed(2) ?? "0.00"}
                        </div>
                        <p className="text-xs text-muted-foreground">
                            Gross: +${stats?.grossProfit?.toFixed(0) ?? 0} / -${stats?.grossLoss?.toFixed(0) ?? 0}
                        </p>
                    </CardContent>
                </Card>

                <Card>
                    <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                        <CardTitle className="text-sm font-medium">Max Drawdown</CardTitle>
                        <Activity className="h-4 w-4 text-muted-foreground" />
                    </CardHeader>
                    <CardContent>
                        <div className="text-2xl font-bold text-red-500">
                            -${stats?.maxDrawdown?.toFixed(2) ?? "0.00"}
                        </div>
                        <p className="text-xs text-muted-foreground">
                            Expectancy: ${stats?.expectancy?.toFixed(2) ?? "0"}/trade
                        </p>
                    </CardContent>
                </Card>
            </div>

            {/* Additional Stats */}
            <div className="grid gap-4 md:grid-cols-3">
                <Card>
                    <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                        <CardTitle className="text-sm font-medium">Average Win</CardTitle>
                        <ArrowUpRight className="h-4 w-4 text-green-500" />
                    </CardHeader>
                    <CardContent>
                        <div className="text-xl font-bold text-green-500">
                            +${stats?.averageWin?.toFixed(2) ?? "0.00"}
                        </div>
                    </CardContent>
                </Card>

                <Card>
                    <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                        <CardTitle className="text-sm font-medium">Average Loss</CardTitle>
                        <ArrowDownRight className="h-4 w-4 text-red-500" />
                    </CardHeader>
                    <CardContent>
                        <div className="text-xl font-bold text-red-500">
                            -${stats?.averageLoss?.toFixed(2) ?? "0.00"}
                        </div>
                    </CardContent>
                </Card>

                <Card>
                    <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                        <CardTitle className="text-sm font-medium">Total Pips</CardTitle>
                        <TrendingUp className="h-4 w-4 text-muted-foreground" />
                    </CardHeader>
                    <CardContent>
                        <div className={`text-xl font-bold ${(stats?.totalPips ?? 0) >= 0 ? 'text-green-500' : 'text-red-500'}`}>
                            {stats?.totalPips?.toFixed(1) ?? "0"} pips
                        </div>
                        <p className="text-xs text-muted-foreground">
                            Avg: {stats?.averagePips?.toFixed(1) ?? "0"} pips/trade
                        </p>
                    </CardContent>
                </Card>
            </div>

            <Tabs defaultValue="breakdown" className="space-y-4">
                <TabsList>
                    <TabsTrigger value="breakdown">EA Breakdown</TabsTrigger>
                    <TabsTrigger value="daily">Daily P/L</TabsTrigger>
                </TabsList>

                <TabsContent value="breakdown">
                    <Card>
                        <CardHeader>
                            <CardTitle className="flex items-center gap-2">
                                <BarChart3 className="h-5 w-5" />
                                Performance by EA
                            </CardTitle>
                            <CardDescription>Profit and trade count for each Expert Advisor</CardDescription>
                        </CardHeader>
                        <CardContent>
                            {data?.eaBreakdown && data.eaBreakdown.length > 0 ? (
                                <div className="space-y-4">
                                    {data.eaBreakdown
                                        .sort((a, b) => b.profit - a.profit)
                                        .map((ea) => (
                                            <div key={ea.eaId} className="flex items-center gap-4 p-3 rounded-lg bg-muted/50">
                                                <div className="flex-1">
                                                    <div className="font-medium">{ea.eaName}</div>
                                                    <div className="text-sm text-muted-foreground">{ea.trades} trades</div>
                                                </div>
                                                <div className="text-right">
                                                    <div className={`font-bold ${ea.profit >= 0 ? 'text-green-500' : 'text-red-500'}`}>
                                                        {ea.profit >= 0 ? '+' : ''}{ea.profit.toFixed(2)}
                                                    </div>
                                                    <div className="text-sm text-muted-foreground">
                                                        {ea.pips >= 0 ? '+' : ''}{ea.pips.toFixed(1)} pips
                                                    </div>
                                                </div>
                                                <Badge variant={ea.profit >= 0 ? "default" : "destructive"}>
                                                    {ea.profit >= 0 ? <TrendingUp className="h-3 w-3" /> : <TrendingDown className="h-3 w-3" />}
                                                </Badge>
                                            </div>
                                        ))}
                                </div>
                            ) : (
                                <div className="text-center py-8 text-muted-foreground">
                                    <BarChart3 className="h-12 w-12 mx-auto mb-4 opacity-50" />
                                    <p>No EA performance data yet</p>
                                    <p className="text-sm">Start trading with EAs to see statistics here</p>
                                </div>
                            )}
                        </CardContent>
                    </Card>
                </TabsContent>

                <TabsContent value="daily">
                    <Card>
                        <CardHeader>
                            <CardTitle className="flex items-center gap-2">
                                <Activity className="h-5 w-5" />
                                Daily Profit/Loss
                            </CardTitle>
                            <CardDescription>Last 30 days of trading activity</CardDescription>
                        </CardHeader>
                        <CardContent>
                            {data?.dailyPL && data.dailyPL.length > 0 ? (
                                <div className="space-y-2">
                                    {data.dailyPL.slice(-14).reverse().map((day) => (
                                        <div key={day.date} className="flex items-center justify-between p-2 rounded bg-muted/30">
                                            <span className="text-sm font-medium">{new Date(day.date).toLocaleDateString()}</span>
                                            <span className={`font-bold ${day.pl >= 0 ? 'text-green-500' : 'text-red-500'}`}>
                                                {day.pl >= 0 ? '+' : ''}{day.pl.toFixed(2)}
                                            </span>
                                        </div>
                                    ))}
                                </div>
                            ) : (
                                <div className="text-center py-8 text-muted-foreground">
                                    <Activity className="h-12 w-12 mx-auto mb-4 opacity-50" />
                                    <p>No daily P/L data yet</p>
                                    <p className="text-sm">Close some trades to see daily statistics</p>
                                </div>
                            )}
                        </CardContent>
                    </Card>
                </TabsContent>
            </Tabs>
        </div>
    )
}
