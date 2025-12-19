"use client"

import { useState, useEffect } from "react"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Switch } from "@/components/ui/switch"
import { Badge } from "@/components/ui/badge"
import { useToast } from "@/hooks/use-toast"
import {
    Bell,
    MessageCircle,
    Loader2,
    CheckCircle2,
    AlertCircle,
    ExternalLink,
    Save,
} from "lucide-react"

interface NotificationSettings {
    telegramChatId: string | null
    telegramUsername: string | null
    telegramVerified: boolean
    discordWebhook: string | null
    notifyTradeOpen: boolean
    notifyTradeClose: boolean
    notifyDailyPL: boolean
    notifyDrawdown: boolean
    drawdownThreshold: number
    dailySummaryTime: string
}

interface SettingsResponse {
    success: boolean
    settings: NotificationSettings
}

// Discord icon component
function DiscordIcon({ className }: { className?: string }) {
    return (
        <svg className={className} viewBox="0 0 24 24" fill="currentColor">
            <path d="M20.317 4.37a19.791 19.791 0 0 0-4.885-1.515.074.074 0 0 0-.079.037c-.21.375-.444.864-.608 1.25a18.27 18.27 0 0 0-5.487 0 12.64 12.64 0 0 0-.617-1.25.077.077 0 0 0-.079-.037A19.736 19.736 0 0 0 3.677 4.37a.07.07 0 0 0-.032.027C.533 9.046-.32 13.58.099 18.057a.082.082 0 0 0 .031.057 19.9 19.9 0 0 0 5.993 3.03.078.078 0 0 0 .084-.028 14.09 14.09 0 0 0 1.226-1.994.076.076 0 0 0-.041-.106 13.107 13.107 0 0 1-1.872-.892.077.077 0 0 1-.008-.128 10.2 10.2 0 0 0 .372-.292.074.074 0 0 1 .077-.01c3.928 1.793 8.18 1.793 12.062 0a.074.074 0 0 1 .078.01c.12.098.246.198.373.292a.077.077 0 0 1-.006.127 12.299 12.299 0 0 1-1.873.892.077.077 0 0 0-.041.107c.36.698.772 1.362 1.225 1.993a.076.076 0 0 0 .084.028 19.839 19.839 0 0 0 6.002-3.03.077.077 0 0 0 .032-.054c.5-5.177-.838-9.674-3.549-13.66a.061.061 0 0 0-.031-.03zM8.02 15.33c-1.183 0-2.157-1.085-2.157-2.419 0-1.333.956-2.419 2.157-2.419 1.21 0 2.176 1.096 2.157 2.42 0 1.333-.956 2.418-2.157 2.418zm7.975 0c-1.183 0-2.157-1.085-2.157-2.419 0-1.333.955-2.419 2.157-2.419 1.21 0 2.176 1.096 2.157 2.42 0 1.333-.946 2.418-2.157 2.418z" />
        </svg>
    )
}

export default function NotificationsPage() {
    const { toast } = useToast()
    const queryClient = useQueryClient()

    const { data, isLoading } = useQuery<SettingsResponse>({
        queryKey: ["notification-settings"],
        queryFn: async () => {
            const res = await fetch("/api/notifications")
            if (!res.ok) throw new Error("Failed to fetch settings")
            return res.json()
        },
    })

    const [discordWebhook, setDiscordWebhook] = useState("")
    const [notifyTradeOpen, setNotifyTradeOpen] = useState(true)
    const [notifyTradeClose, setNotifyTradeClose] = useState(true)
    const [notifyDailyPL, setNotifyDailyPL] = useState(true)
    const [notifyDrawdown, setNotifyDrawdown] = useState(true)
    const [drawdownThreshold, setDrawdownThreshold] = useState(10)

    // Update local state when data loads
    useEffect(() => {
        if (data?.settings) {
            setDiscordWebhook(data.settings.discordWebhook || "")
            setNotifyTradeOpen(data.settings.notifyTradeOpen)
            setNotifyTradeClose(data.settings.notifyTradeClose)
            setNotifyDailyPL(data.settings.notifyDailyPL)
            setNotifyDrawdown(data.settings.notifyDrawdown)
            setDrawdownThreshold(data.settings.drawdownThreshold)
        }
    }, [data])

    const updateMutation = useMutation({
        mutationFn: async (settings: Partial<NotificationSettings>) => {
            const res = await fetch("/api/notifications", {
                method: "PATCH",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify(settings),
            })
            if (!res.ok) throw new Error("Failed to update settings")
            return res.json()
        },
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ["notification-settings"] })
            toast({ title: "Success", description: "Notification settings saved" })
        },
        onError: () => {
            toast({ title: "Error", description: "Failed to save settings", variant: "destructive" })
        },
    })

    const handleSave = () => {
        updateMutation.mutate({
            discordWebhook: discordWebhook || null,
            notifyTradeOpen,
            notifyTradeClose,
            notifyDailyPL,
            notifyDrawdown,
            drawdownThreshold,
        })
    }

    const testDiscord = async () => {
        if (!discordWebhook) {
            toast({ title: "Error", description: "Enter a Discord webhook URL first", variant: "destructive" })
            return
        }

        try {
            const response = await fetch(discordWebhook, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    content: "🎉 **My Algo Stack** - Test notification successful!",
                    embeds: [{
                        title: "Connection Verified",
                        description: "Your Discord webhook is working correctly. You will receive trade alerts here.",
                        color: 5763719, // Green
                    }],
                }),
            })

            if (response.ok) {
                toast({ title: "Success", description: "Test message sent to Discord!" })
            } else {
                throw new Error("Failed to send")
            }
        } catch {
            toast({ title: "Error", description: "Failed to send test message. Check your webhook URL.", variant: "destructive" })
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
                <h2 className="text-3xl font-bold tracking-tight">Notifications</h2>
                <p className="text-muted-foreground">
                    Configure how you receive trade alerts and daily summaries
                </p>
            </div>

            {/* Telegram Card */}
            <Card>
                <CardHeader>
                    <CardTitle className="flex items-center gap-2">
                        <MessageCircle className="h-5 w-5 text-[#0088cc]" />
                        Telegram
                        {data?.settings.telegramVerified ? (
                            <Badge variant="default" className="ml-2">
                                <CheckCircle2 className="h-3 w-3 mr-1" /> Connected
                            </Badge>
                        ) : (
                            <Badge variant="secondary" className="ml-2">
                                <AlertCircle className="h-3 w-3 mr-1" /> Not Connected
                            </Badge>
                        )}
                    </CardTitle>
                    <CardDescription>
                        Receive instant trade alerts via Telegram
                    </CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                    <div className="p-4 rounded-lg bg-muted/50 border">
                        <h4 className="font-medium mb-2">How to Connect Telegram</h4>
                        <ol className="text-sm text-muted-foreground space-y-2 list-decimal list-inside">
                            <li>Open Telegram and search for <code className="bg-muted px-1 rounded">@MyAlgoStackBot</code></li>
                            <li>Start a conversation and send <code className="bg-muted px-1 rounded">/start</code></li>
                            <li>The bot will provide your verification code</li>
                            <li>Enter the code below to verify your account</li>
                        </ol>
                        <Button variant="outline" className="mt-3" disabled>
                            <ExternalLink className="h-4 w-4 mr-2" />
                            Coming Soon
                        </Button>
                    </div>
                </CardContent>
            </Card>

            {/* Discord Card */}
            <Card>
                <CardHeader>
                    <CardTitle className="flex items-center gap-2">
                        <DiscordIcon className="h-5 w-5 text-[#5865F2]" />
                        Discord
                        {discordWebhook ? (
                            <Badge variant="default" className="ml-2">
                                <CheckCircle2 className="h-3 w-3 mr-1" /> Configured
                            </Badge>
                        ) : (
                            <Badge variant="secondary" className="ml-2">Not Configured</Badge>
                        )}
                    </CardTitle>
                    <CardDescription>
                        Send trade alerts to your Discord server
                    </CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                    <div className="space-y-2">
                        <Label htmlFor="discord-webhook">Webhook URL</Label>
                        <div className="flex gap-2">
                            <Input
                                id="discord-webhook"
                                type="url"
                                placeholder="https://discord.com/api/webhooks/..."
                                value={discordWebhook}
                                onChange={(e) => setDiscordWebhook(e.target.value)}
                            />
                            <Button variant="outline" onClick={testDiscord} disabled={!discordWebhook}>
                                Test
                            </Button>
                        </div>
                        <p className="text-xs text-muted-foreground">
                            Create a webhook in Discord: Server Settings → Integrations → Webhooks
                        </p>
                    </div>
                </CardContent>
            </Card>

            {/* Alert Preferences */}
            <Card>
                <CardHeader>
                    <CardTitle className="flex items-center gap-2">
                        <Bell className="h-5 w-5" />
                        Alert Preferences
                    </CardTitle>
                    <CardDescription>
                        Choose which notifications you want to receive
                    </CardDescription>
                </CardHeader>
                <CardContent className="space-y-6">
                    <div className="flex items-center justify-between">
                        <div className="space-y-0.5">
                            <Label>Trade Open</Label>
                            <p className="text-sm text-muted-foreground">Get notified when a new trade is opened</p>
                        </div>
                        <Switch
                            checked={notifyTradeOpen}
                            onCheckedChange={setNotifyTradeOpen}
                        />
                    </div>

                    <div className="flex items-center justify-between">
                        <div className="space-y-0.5">
                            <Label>Trade Close</Label>
                            <p className="text-sm text-muted-foreground">Get notified when a trade is closed with P/L</p>
                        </div>
                        <Switch
                            checked={notifyTradeClose}
                            onCheckedChange={setNotifyTradeClose}
                        />
                    </div>

                    <div className="flex items-center justify-between">
                        <div className="space-y-0.5">
                            <Label>Daily P/L Summary</Label>
                            <p className="text-sm text-muted-foreground">Receive a daily summary of your trading</p>
                        </div>
                        <Switch
                            checked={notifyDailyPL}
                            onCheckedChange={setNotifyDailyPL}
                        />
                    </div>

                    <div className="flex items-center justify-between">
                        <div className="space-y-0.5">
                            <Label>Drawdown Alert</Label>
                            <p className="text-sm text-muted-foreground">
                                Alert when account drawdown exceeds threshold
                            </p>
                        </div>
                        <Switch
                            checked={notifyDrawdown}
                            onCheckedChange={setNotifyDrawdown}
                        />
                    </div>

                    {notifyDrawdown && (
                        <div className="ml-6 space-y-2">
                            <Label htmlFor="drawdown-threshold">Drawdown Threshold (%)</Label>
                            <Input
                                id="drawdown-threshold"
                                type="number"
                                min={1}
                                max={100}
                                value={drawdownThreshold}
                                onChange={(e) => setDrawdownThreshold(Number(e.target.value))}
                                className="w-24"
                            />
                        </div>
                    )}
                </CardContent>
            </Card>

            {/* Save Button */}
            <div className="flex justify-end">
                <Button onClick={handleSave} disabled={updateMutation.isPending}>
                    {updateMutation.isPending ? (
                        <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                    ) : (
                        <Save className="h-4 w-4 mr-2" />
                    )}
                    Save Settings
                </Button>
            </div>
        </div>
    )
}
