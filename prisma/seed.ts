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
    // Advanced EAs (11-20)
    {
      eaCode: "multi_timeframe_ea",
      name: "Multi-Timeframe EA",
      description: "Multi-timeframe trend alignment strategy. Uses H4 for major trend (50 EMA), H1 for intermediate (20 EMA), and M15 RSI for entry timing. Only trades when all timeframes agree. Best for major pairs.",
      currentVersion: "1.0.0",
    },
    {
      eaCode: "fibonacci_retracement_ea",
      name: "Fibonacci Retracement EA",
      description: "Fibonacci retracement trading. Identifies swing highs/lows, calculates 38.2%, 50%, 61.8% levels, and trades bounces with candlestick confirmation. Best on H1-H4 timeframes.",
      currentVersion: "1.0.0",
    },
    {
      eaCode: "price_action_ea",
      name: "Price Action EA",
      description: "Pure price action pattern recognition. Detects Pin Bars (Hammer/Shooting Star) and Engulfing patterns at key support/resistance levels. No indicators needed. Best on H4-Daily.",
      currentVersion: "1.0.0",
    },
    {
      eaCode: "momentum_breakout_ea",
      name: "Momentum Breakout EA",
      description: "Momentum-confirmed breakouts using CCI and volume analysis. Only trades breakouts with CCI > 100 (or < -100) and volume spike > 1.5x average. Uses ATR trailing stop. Best on H1.",
      currentVersion: "1.0.0",
    },
    {
      eaCode: "london_breakout_ea",
      name: "London Breakout EA",
      description: "London session breakout strategy. Calculates Asian session range (00:00-07:00), trades breakouts during London open. Closes all trades at end of London session. Best for GBP pairs.",
      currentVersion: "1.0.0",
    },
    {
      eaCode: "mean_reversion_ea",
      name: "Mean Reversion EA",
      description: "Statistical mean reversion using Z-Score. Trades when price deviates > 2 standard deviations from the mean. Exits when Z-Score returns to 0. Best for range-bound pairs like EURCHF.",
      currentVersion: "1.0.0",
    },
    {
      eaCode: "keltner_channel_ea",
      name: "Keltner Channel EA",
      description: "Keltner Channel (EMA + ATR bands) pullback strategy. Determines trend by price position, enters on pullback to middle line. TP at opposite band. Best on H1-H4 trending pairs.",
      currentVersion: "1.0.0",
    },
    {
      eaCode: "williams_r_ea",
      name: "Williams %R EA",
      description: "Williams %R with trend filter. Uses 100 EMA for trend direction, trades %R extremes (-80 oversold, -20 overbought) in trend direction. Exits at opposite extreme. Best on H1-H4.",
      currentVersion: "1.0.0",
    },
    {
      eaCode: "parabolic_sar_ea",
      name: "Parabolic SAR EA",
      description: "Parabolic SAR trend following with ADX filter. Enters on SAR flip when ADX > 25. Uses SAR as dynamic trailing stop. Rides trends until SAR flips. Best on H1-H4.",
      currentVersion: "1.0.0",
    },
    {
      eaCode: "hedge_ea",
      name: "Hedge EA",
      description: "Hedging strategy that opens both buy and sell simultaneously. Closes losing side when ADX confirms trend (> 30). Trails winning side with ATR stop. Requires hedging-enabled broker.",
      currentVersion: "1.0.0",
    },
    // Martingale EAs (21-30) - HIGH RISK
    {
      eaCode: "classic_martingale_ea",
      name: "Classic Martingale EA",
      description: "Classic martingale that doubles lot after each loss. Resets on win. Includes daily loss limit and max trades. WARNING: VERY HIGH RISK - requires large account balance.",
      currentVersion: "1.0.0",
    },
    {
      eaCode: "anti_martingale_ea",
      name: "Anti-Martingale EA",
      description: "Reverse martingale - increases lot after wins, resets after losses. Capitalizes on winning streaks while limiting losses. Safer than classic martingale.",
      currentVersion: "1.0.0",
    },
    {
      eaCode: "smooth_martingale_ea",
      name: "Smooth Martingale EA",
      description: "Gentler martingale using 1.3x multiplier instead of 2x. More gradual progression allows more trades before max lot. Includes equity stop protection.",
      currentVersion: "1.0.0",
    },
    {
      eaCode: "grid_martingale_ea",
      name: "Grid Martingale EA",
      description: "Combines grid trading with martingale. Opens positions at fixed intervals with increasing lots. Closes all when profit target reached. VERY HIGH RISK.",
      currentVersion: "1.0.0",
    },
    {
      eaCode: "fibonacci_martingale_ea",
      name: "Fibonacci Martingale EA",
      description: "Uses Fibonacci sequence (1,1,2,3,5,8...) for lot sizing. More gradual than 2x doubling. Goes back 2 levels on win for faster recovery.",
      currentVersion: "1.0.0",
    },
    {
      eaCode: "dalembert_martingale_ea",
      name: "D'Alembert Martingale EA",
      description: "Linear progression: +1 unit on loss, -1 unit on win. More conservative than exponential martingale. Lower capital requirements.",
      currentVersion: "1.0.0",
    },
    {
      eaCode: "labouchere_martingale_ea",
      name: "Labouchere Martingale EA",
      description: "Cancellation system using number sequence. Win: remove ends. Loss: add bet to end. Goal is to empty the sequence for guaranteed profit.",
      currentVersion: "1.0.0",
    },
    {
      eaCode: "parlay_martingale_ea",
      name: "Parlay Martingale EA",
      description: "Let It Ride strategy - reinvests profits into next trade. Great for winning streaks. Limited risk as only base lot is at risk on losses.",
      currentVersion: "1.0.0",
    },
    {
      eaCode: "oscar_grind_martingale_ea",
      name: "Oscar's Grind Martingale EA",
      description: "Conservative system aiming for 1 unit profit per cycle. Same bet on loss, +1 on win. Resets when target reached. Lower variance.",
      currentVersion: "1.0.0",
    },
    {
      eaCode: "hybrid_martingale_ea",
      name: "Hybrid Martingale EA",
      description: "Smart martingale that switches strategies based on market. Trending: anti-martingale. Ranging: classic martingale. Includes cooling period and safety stops.",
      currentVersion: "1.0.0",
    },
    // Utility EAs (31-40)
    {
      eaCode: "trade_manager_ea",
      name: "Trade Manager EA",
      description: "Comprehensive trade management utility. Features: ATR-based trailing stops, break-even automation, partial close at targets, time-based exits. Works with any trades.",
      currentVersion: "1.0.0",
    },
    {
      eaCode: "risk_calculator_ea",
      name: "Risk Calculator EA",
      description: "Real-time position size calculator based on risk percentage. Displays optimal lot size, pip value, margin requirements. One-click trading buttons included.",
      currentVersion: "1.0.0",
    },
    {
      eaCode: "news_filter_utility_ea",
      name: "News Filter Utility EA",
      description: "Trading hours and news filter manager. Controls trading based on sessions, Friday close, Monday delay. Can pause or close trades during restricted times.",
      currentVersion: "1.0.0",
    },
    {
      eaCode: "equity_protector_ea",
      name: "Equity Protector EA",
      description: "Account protection utility. Monitors drawdown, daily loss limits, and profit targets. Closes all trades when limits reached. Essential for risk management.",
      currentVersion: "1.0.0",
    },
    {
      eaCode: "spread_monitor_ea",
      name: "Spread Monitor EA",
      description: "Real-time spread monitoring with alerts. Tracks min/max/average spread, alerts when spread exceeds limits. Helps avoid trading during high spread periods.",
      currentVersion: "1.0.0",
    },
    {
      eaCode: "trade_copier_ea",
      name: "Trade Copier EA",
      description: "Local trade copier between MT terminals. Master/Slave mode, lot multiplier, reverse copy option. Copy trades between accounts on the same computer.",
      currentVersion: "1.0.0",
    },
    {
      eaCode: "session_trader_ea",
      name: "Session Trader EA",
      description: "Trading session indicator showing Sydney, Tokyo, London, NY sessions. Highlights overlaps (best trading times), countdown to next session.",
      currentVersion: "1.0.0",
    },
    {
      eaCode: "order_block_finder_ea",
      name: "Order Block Finder EA",
      description: "Automatically identifies and draws order blocks (supply/demand zones). Alerts when price approaches zones. Essential for institutional trading concepts.",
      currentVersion: "1.0.0",
    },
    {
      eaCode: "auto_lot_calculator_ea",
      name: "Auto Lot Calculator EA",
      description: "Advanced position sizing with multiple methods: Fixed Risk %, Fixed Fractional, Kelly Criterion. Automatically calculates optimal lot for any trade.",
      currentVersion: "1.0.0",
    },
    {
      eaCode: "trade_journal_ea",
      name: "Trade Journal EA",
      description: "Automatic trade logging and statistics. Exports to CSV, calculates win rate, profit factor, expectancy, max drawdown. Essential for performance analysis.",
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
