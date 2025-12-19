/**
 * Notification Service
 * Handles sending notifications to Telegram and Discord
 */

interface TradeNotification {
    type: "OPEN" | "CLOSE"
    symbol: string
    tradeType: "BUY" | "SELL"
    lots: number
    price: number
    profit?: number
    pips?: number
    eaName?: string
    accountNumber: string
}

interface DailySummaryNotification {
    date: string
    trades: number
    profit: number
    pips: number
    winRate: number
}

interface DrawdownNotification {
    currentDrawdown: number
    threshold: number
    accountBalance: number
    peakBalance: number
}

// Discord colors
const DISCORD_COLORS = {
    GREEN: 5763719,  // #57F287
    RED: 15548997,   // #ED4245
    BLUE: 5793266,   // #5865F2
    YELLOW: 16776960, // #FFFF00
}

/**
 * Send a notification to Discord webhook
 */
export async function sendDiscordNotification(
    webhookUrl: string,
    content: string,
    embed?: {
        title: string
        description: string
        color: number
        fields?: { name: string; value: string; inline?: boolean }[]
    }
): Promise<boolean> {
    try {
        const payload: { content: string; embeds?: object[] } = { content }

        if (embed) {
            payload.embeds = [{
                title: embed.title,
                description: embed.description,
                color: embed.color,
                fields: embed.fields,
                timestamp: new Date().toISOString(),
                footer: { text: "My Algo Stack" },
            }]
        }

        const response = await fetch(webhookUrl, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(payload),
        })

        return response.ok
    } catch (error) {
        console.error("Discord notification error:", error)
        return false
    }
}

/**
 * Send trade open/close notification
 */
export async function sendTradeNotification(
    webhookUrl: string,
    trade: TradeNotification
): Promise<boolean> {
    const isOpen = trade.type === "OPEN"
    const isBuy = trade.tradeType === "BUY"

    const emoji = isOpen
        ? (isBuy ? "🟢" : "🔴")
        : (trade.profit && trade.profit > 0 ? "✅" : "❌")

    const title = isOpen
        ? `${emoji} Trade Opened`
        : `${emoji} Trade Closed`

    const color = isOpen
        ? DISCORD_COLORS.BLUE
        : (trade.profit && trade.profit > 0 ? DISCORD_COLORS.GREEN : DISCORD_COLORS.RED)

    const fields = [
        { name: "Symbol", value: trade.symbol, inline: true },
        { name: "Type", value: trade.tradeType, inline: true },
        { name: "Lots", value: trade.lots.toFixed(2), inline: true },
        { name: "Price", value: trade.price.toFixed(5), inline: true },
    ]

    if (!isOpen && trade.profit !== undefined) {
        fields.push({
            name: "Profit",
            value: `${trade.profit >= 0 ? "+" : ""}$${trade.profit.toFixed(2)}`,
            inline: true
        })
    }

    if (!isOpen && trade.pips !== undefined) {
        fields.push({
            name: "Pips",
            value: `${trade.pips >= 0 ? "+" : ""}${trade.pips.toFixed(1)}`,
            inline: true
        })
    }

    if (trade.eaName) {
        fields.push({ name: "EA", value: trade.eaName, inline: true })
    }

    fields.push({ name: "Account", value: trade.accountNumber, inline: true })

    return sendDiscordNotification(webhookUrl, "", {
        title,
        description: isOpen
            ? `Opened ${trade.tradeType} position on ${trade.symbol}`
            : `Closed ${trade.tradeType} position on ${trade.symbol}`,
        color,
        fields,
    })
}

/**
 * Send daily P/L summary notification
 */
export async function sendDailySummaryNotification(
    webhookUrl: string,
    summary: DailySummaryNotification
): Promise<boolean> {
    const isProfitable = summary.profit >= 0

    return sendDiscordNotification(webhookUrl, "", {
        title: `📊 Daily Summary - ${summary.date}`,
        description: `${isProfitable ? "✅ Profitable" : "❌ Loss"} trading day`,
        color: isProfitable ? DISCORD_COLORS.GREEN : DISCORD_COLORS.RED,
        fields: [
            { name: "Total Trades", value: summary.trades.toString(), inline: true },
            { name: "Net P/L", value: `${isProfitable ? "+" : ""}$${summary.profit.toFixed(2)}`, inline: true },
            { name: "Pips", value: `${summary.pips >= 0 ? "+" : ""}${summary.pips.toFixed(1)}`, inline: true },
            { name: "Win Rate", value: `${summary.winRate.toFixed(1)}%`, inline: true },
        ],
    })
}

/**
 * Send drawdown alert notification
 */
export async function sendDrawdownNotification(
    webhookUrl: string,
    drawdown: DrawdownNotification
): Promise<boolean> {
    return sendDiscordNotification(webhookUrl, "⚠️ **DRAWDOWN ALERT**", {
        title: "⚠️ Drawdown Threshold Exceeded",
        description: `Your account drawdown has exceeded ${drawdown.threshold}%`,
        color: DISCORD_COLORS.YELLOW,
        fields: [
            { name: "Current Drawdown", value: `${drawdown.currentDrawdown.toFixed(2)}%`, inline: true },
            { name: "Threshold", value: `${drawdown.threshold}%`, inline: true },
            { name: "Peak Balance", value: `$${drawdown.peakBalance.toFixed(2)}`, inline: true },
            { name: "Current Balance", value: `$${drawdown.accountBalance.toFixed(2)}`, inline: true },
        ],
    })
}

// Telegram functions (placeholder for future implementation)
export async function sendTelegramNotification(
    chatId: string,
    botToken: string,
    message: string
): Promise<boolean> {
    try {
        const response = await fetch(
            `https://api.telegram.org/bot${botToken}/sendMessage`,
            {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    chat_id: chatId,
                    text: message,
                    parse_mode: "HTML",
                }),
            }
        )
        return response.ok
    } catch (error) {
        console.error("Telegram notification error:", error)
        return false
    }
}
