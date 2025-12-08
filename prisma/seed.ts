import { PrismaClient } from "@prisma/client"
import { hash } from "bcryptjs"

const prisma = new PrismaClient()

async function main() {
  console.log("Seeding database...")

  // Create admin user
  const adminPassword = await hash("admin123", 12)
  const admin = await prisma.user.upsert({
    where: { email: "admin@example.com" },
    update: {},
    create: {
      email: "admin@example.com",
      name: "Admin User",
      passwordHash: adminPassword,
      role: "ADMIN",
      isApproved: true,
      isActive: true,
      subscriptionTier: "TIER_3",
    },
  })
  console.log("Created admin user:", admin.email)

  // Create all 10 EAs
  const sampleEAs = [
    {
      eaCode: "ma_crossover_ea",
      name: "MA Crossover EA",
      description: "Moving Average Crossover strategy. Buy when fast MA crosses above slow MA, sell when crosses below. Uses EMA for faster response. Best on H1 timeframe with major pairs.",
      currentVersion: "1.0.0",
    },
    {
      eaCode: "rsi_reversal_ea",
      name: "RSI Reversal EA",
      description: "RSI Overbought/Oversold mean reversion strategy. Buy when RSI crosses above 30, sell when crosses below 70. Best on H4 timeframe with range-bound pairs.",
      currentVersion: "1.0.0",
    },
    {
      eaCode: "bollinger_breakout_ea",
      name: "Bollinger Breakout EA",
      description: "Bollinger Bands breakout strategy. Buy on upper band breakout, sell on lower band breakout. Exits when price returns to middle band. Best on H1 with trending pairs.",
      currentVersion: "1.0.0",
    },
    {
      eaCode: "macd_divergence_ea",
      name: "MACD Divergence EA",
      description: "MACD Histogram zero-line crossover strategy. Buy on positive crossover, sell on negative. Closes on opposite signal. Best on H4 with all major pairs.",
      currentVersion: "1.0.0",
    },
    {
      eaCode: "stochastic_scalper_ea",
      name: "Stochastic Scalper EA",
      description: "Stochastic scalping strategy. Quick trades on %K/%D crossovers in overbought/oversold zones. Best on M15 with high liquidity pairs like EURUSD.",
      currentVersion: "1.0.0",
    },
    {
      eaCode: "atr_trailing_ea",
      name: "ATR Trailing EA",
      description: "ATR-based trailing stop strategy. Enters on trend confirmation (price vs MA), uses ATR multiplier for dynamic trailing. No fixed TP, rides trends. Best on H1-H4.",
      currentVersion: "1.0.0",
    },
    {
      eaCode: "support_resistance_ea",
      name: "Support Resistance EA",
      description: "Support/Resistance bounce trading. Identifies S/R from recent highs/lows, buys at support with bullish confirmation, sells at resistance with bearish. Best on H1-H4.",
      currentVersion: "1.0.0",
    },
    {
      eaCode: "ichimoku_cloud_ea",
      name: "Ichimoku Cloud EA",
      description: "Ichimoku Cloud trading system. Buy when price above cloud and Tenkan crosses above Kijun. Strong trend-following. Best on H4-D1 with trending pairs.",
      currentVersion: "1.0.0",
    },
    {
      eaCode: "grid_recovery_ea",
      name: "Grid Recovery EA",
      description: "Grid trading with martingale recovery. Opens grid orders at intervals, increases lot on drawdown, closes all at profit target. HIGH RISK - use with caution!",
      currentVersion: "1.0.0",
    },
    {
      eaCode: "news_filter_ea",
      name: "News Filter EA",
      description: "Breakout strategy with volatility filter. Uses ADX to confirm trends, includes time filter to avoid news. Trades range breakouts with DI confirmation. Best on M30-H1.",
      currentVersion: "1.0.0",
    },
  ]

  for (const ea of sampleEAs) {
    const created = await prisma.expertAdvisor.upsert({
      where: { eaCode: ea.eaCode },
      update: {},
      create: ea,
    })
    console.log("Created EA:", created.name)
  }

  // Grant admin access to all EAs
  const allEAs = await prisma.expertAdvisor.findMany()
  for (const ea of allEAs) {
    await prisma.userEaAccess.upsert({
      where: {
        userId_eaId: {
          userId: admin.id,
          eaId: ea.id,
        },
      },
      update: {},
      create: {
        userId: admin.id,
        eaId: ea.id,
      },
    })
  }
  console.log("Granted admin access to all EAs")

  console.log("Seeding completed!")
}

main()
  .catch((e) => {
    console.error(e)
    process.exit(1)
  })
  .finally(async () => {
    await prisma.$disconnect()
  })
