import { NextRequest, NextResponse } from "next/server"
import { getServerSession } from "next-auth"
import { authOptions } from "@/lib/auth"
import { prisma } from "@/lib/db"
import { readFileSync, existsSync } from "fs"
import { join } from "path"

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ eaCode: string }> }
) {
  try {
    const session = await getServerSession(authOptions)
    if (!session?.user?.id) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
    }

    const { eaCode } = await params
    const terminal = request.nextUrl.searchParams.get("terminal") as "MT4" | "MT5"

    if (!terminal || !["MT4", "MT5"].includes(terminal)) {
      return NextResponse.json({ error: "Invalid terminal type" }, { status: 400 })
    }

    // Find EA by eaCode or by matching name pattern
    const ea = await prisma.expertAdvisor.findUnique({
      where: { eaCode },
    })

    if (!ea || !ea.isActive) {
      return NextResponse.json({ error: "EA not found" }, { status: 404 })
    }

    // Check user access
    const access = await prisma.userEaAccess.findFirst({
      where: {
        userId: session.user.id,
        eaId: ea.id,
        isEnabled: true,
        OR: [
          { expiresAt: null },
          { expiresAt: { gt: new Date() } },
        ],
      },
    })

    if (!access) {
      return NextResponse.json({ error: "Access denied" }, { status: 403 })
    }

    // Map eaCode to file name pattern
    const eaCodeToFileMap: Record<string, string> = {
      // Basic EAs (1-10)
      "ma_crossover_ea": "01_MA_Crossover_EA",
      "rsi_reversal_ea": "02_RSI_Reversal_EA",
      "bollinger_breakout_ea": "03_Bollinger_Breakout_EA",
      "macd_divergence_ea": "04_MACD_Divergence_EA",
      "stochastic_scalper_ea": "05_Stochastic_Scalper_EA",
      "atr_trailing_ea": "06_ATR_Trailing_EA",
      "support_resistance_ea": "07_Support_Resistance_EA",
      "ichimoku_cloud_ea": "08_Ichimoku_Cloud_EA",
      "grid_recovery_ea": "09_Grid_Recovery_EA",
      "news_filter_ea": "10_News_Filter_EA",
      // Advanced EAs (11-20)
      "multi_timeframe_ea": "11_Multi_Timeframe_EA",
      "fibonacci_retracement_ea": "12_Fibonacci_Retracement_EA",
      "price_action_ea": "13_Price_Action_EA",
      "momentum_breakout_ea": "14_Momentum_Breakout_EA",
      "london_breakout_ea": "15_London_Breakout_EA",
      "mean_reversion_ea": "16_Mean_Reversion_EA",
      "keltner_channel_ea": "17_Keltner_Channel_EA",
      "williams_r_ea": "18_Williams_R_EA",
      "parabolic_sar_ea": "19_Parabolic_SAR_EA",
      "hedge_ea": "20_Hedge_EA",
      // Martingale EAs (21-30)
      "classic_martingale_ea": "21_Classic_Martingale_EA",
      "anti_martingale_ea": "22_Anti_Martingale_EA",
      "smooth_martingale_ea": "23_Smooth_Martingale_EA",
      "grid_martingale_ea": "24_Grid_Martingale_EA",
      "fibonacci_martingale_ea": "25_Fibonacci_Martingale_EA",
      "dalembert_martingale_ea": "26_DAlembert_Martingale_EA",
      "labouchere_martingale_ea": "27_Labouchere_Martingale_EA",
      "parlay_martingale_ea": "28_Parlay_Martingale_EA",
      "oscar_grind_martingale_ea": "29_Oscar_Grind_Martingale_EA",
      "hybrid_martingale_ea": "30_Hybrid_Martingale_EA",
      // Utility EAs (31-40)
      "trade_manager_ea": "31_Trade_Manager_EA",
      "risk_calculator_ea": "32_Risk_Calculator_EA",
      "news_filter_utility_ea": "33_News_Filter_Utility_EA",
      "equity_protector_ea": "34_Equity_Protector_EA",
      "spread_monitor_ea": "35_Spread_Monitor_EA",
      "trade_copier_ea": "36_Trade_Copier_EA",
      "session_trader_ea": "37_Session_Trader_EA",
      "order_block_finder_ea": "38_Order_Block_Finder_EA",
      "auto_lot_calculator_ea": "39_Auto_Lot_Calculator_EA",
      "trade_journal_ea": "40_Trade_Journal_EA",
      // Additional EAs (41-43)
      "scalper_pro_v1": "41_Scalper_Pro_EA",
      "trend_master_v2": "42_Trend_Master_EA",
      "grid_trader_v1": "43_Grid_Trader_EA",
    }

    const fileBaseName = eaCodeToFileMap[eaCode]
    if (!fileBaseName) {
      return NextResponse.json({ error: "EA file mapping not found" }, { status: 404 })
    }

    const extension = terminal === "MT4" ? "ex4" : "ex5"
    const folderName = terminal === "MT4" ? "MQL4" : "MQL5"
    const fileName = `${fileBaseName}.${extension}`
    const filePath = join(process.cwd(), "mql", folderName, "Experts", fileName)

    console.log(`[Download Debug] Request for eaCode: ${eaCode}, Terminal: ${terminal}`)
    console.log(`[Download Debug] Mapped to file: ${fileName}`)
    console.log(`[Download Debug] Full path: ${filePath}`)
    console.log(`[Download Debug] Exists: ${existsSync(filePath)}`)


    if (!existsSync(filePath)) {
      return NextResponse.json(
        { error: `${terminal} file not available for this EA` },
        { status: 404 }
      )
    }

    // Read the file
    const fileContent = readFileSync(filePath)

    // Return the file as a download
    return new NextResponse(fileContent, {
      headers: {
        "Content-Type": "application/octet-stream",
        "Content-Disposition": `attachment; filename="${fileName}"`,
      },
    })
  } catch (error) {
    console.error("Download EA error:", error)
    return NextResponse.json({ error: "Download failed" }, { status: 500 })
  }
}
