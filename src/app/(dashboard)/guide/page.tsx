"use client"

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { 
  Download, 
  Key, 
  Settings, 
  Play, 
  CheckCircle2, 
  AlertTriangle,
  FileCode,
  Shield,
  ArrowRight,
} from "lucide-react"
import Link from "next/link"

const steps = [
  {
    number: 1,
    title: "Get Your API Credentials",
    description: "Generate your unique API Key and Secret from the API Keys page. These credentials are used to validate your EA licenses.",
    icon: Key,
    action: { label: "Go to API Keys", href: "/api-keys" },
    tips: [
      "Keep your API Secret secure - it's only shown once",
      "You can regenerate credentials if needed",
      "Each user gets unique credentials"
    ]
  },
  {
    number: 2,
    title: "Download Expert Advisors",
    description: "Browse and download the Expert Advisors you have access to. Choose between MT4 (.mq4) and MT5 (.mq5) versions.",
    icon: Download,
    action: { label: "Go to Downloads", href: "/downloads" },
    tips: [
      "Download the correct version for your terminal",
      "MT4 files end with .mq4, MT5 files end with .mq5",
      "You can download all EAs at once"
    ]
  },
  {
    number: 3,
    title: "Install in MetaTrader",
    description: "Copy the downloaded .mq4/.mq5 files to your MetaTrader's Experts folder and compile them.",
    icon: FileCode,
    action: null,
    tips: [
      "MT4: File → Open Data Folder → MQL4 → Experts",
      "MT5: File → Open Data Folder → MQL5 → Experts",
      "Press F7 in MetaEditor to compile",
      "Restart MetaTrader after adding new EAs"
    ]
  },
  {
    number: 4,
    title: "Configure EA Settings",
    description: "Attach the EA to a chart and enter your API Key and Secret in the EA's input parameters.",
    icon: Settings,
    action: null,
    tips: [
      "Drag the EA from Navigator to a chart",
      "Enter EA_ApiKey and EA_ApiSecret",
      "Enable 'Allow DLL imports' if prompted",
      "Enable 'Allow WebRequest' for the license server"
    ]
  },
  {
    number: 5,
    title: "Start Trading",
    description: "Once configured, the EA will validate your license and start trading according to its strategy.",
    icon: Play,
    action: null,
    tips: [
      "Check the Experts tab for validation messages",
      "Use a demo account first to test",
      "Monitor the EA's performance regularly"
    ]
  }
]

const categories = [
  {
    name: "Basic Strategies (1-10)",
    description: "Fundamental trading strategies using common indicators",
    examples: ["MA Crossover", "RSI Reversal", "Bollinger Breakout"],
    risk: "Low to Medium",
    color: "bg-green-500/10 text-green-500"
  },
  {
    name: "Advanced Strategies (11-20)",
    description: "Sophisticated systems with multiple confirmations",
    examples: ["Multi-Timeframe", "Price Action", "London Breakout"],
    risk: "Medium",
    color: "bg-purple-500/10 text-purple-500"
  },
  {
    name: "Martingale Strategies (21-30)",
    description: "High-risk strategies that increase position sizes",
    examples: ["Classic Martingale", "Fibonacci Martingale", "Grid Martingale"],
    risk: "HIGH - Use with caution",
    color: "bg-red-500/10 text-red-500"
  },
  {
    name: "Utilities & Tools (31-40)",
    description: "Helper tools for trade management and analysis",
    examples: ["Trade Manager", "Risk Calculator", "Trade Journal"],
    risk: "N/A - Not trading EAs",
    color: "bg-blue-500/10 text-blue-500"
  }
]

export default function GuidePage() {
  return (
    <div className="space-y-8">
      <div>
        <h2 className="text-3xl font-bold tracking-tight">Quick Start Guide</h2>
        <p className="text-muted-foreground">
          Get started with your Expert Advisors in 5 easy steps
        </p>
      </div>

      {/* Steps */}
      <div className="space-y-4">
        {steps.map((step) => (
          <Card key={step.number}>
            <CardHeader>
              <div className="flex items-start gap-4">
                <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-primary text-primary-foreground font-bold">
                  {step.number}
                </div>
                <div className="flex-1">
                  <div className="flex items-center gap-2">
                    <step.icon className="h-5 w-5 text-primary" />
                    <CardTitle>{step.title}</CardTitle>
                  </div>
                  <CardDescription className="mt-1">{step.description}</CardDescription>
                </div>
                {step.action && (
                  <Link href={step.action.href}>
                    <Button variant="outline" size="sm">
                      {step.action.label}
                      <ArrowRight className="ml-2 h-4 w-4" />
                    </Button>
                  </Link>
                )}
              </div>
            </CardHeader>
            <CardContent>
              <div className="ml-14 space-y-2">
                {step.tips.map((tip, i) => (
                  <div key={i} className="flex items-start gap-2 text-sm text-muted-foreground">
                    <CheckCircle2 className="h-4 w-4 shrink-0 text-green-500 mt-0.5" />
                    <span>{tip}</span>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        ))}
      </div>

      {/* EA Categories */}
      <div>
        <h3 className="text-xl font-semibold mb-4">EA Categories</h3>
        <div className="grid gap-4 md:grid-cols-2">
          {categories.map((cat) => (
            <Card key={cat.name}>
              <CardHeader>
                <CardTitle className="text-lg">{cat.name}</CardTitle>
                <CardDescription>{cat.description}</CardDescription>
              </CardHeader>
              <CardContent className="space-y-3">
                <div>
                  <span className="text-sm font-medium">Examples: </span>
                  <span className="text-sm text-muted-foreground">{cat.examples.join(", ")}</span>
                </div>
                <div className="flex items-center gap-2">
                  <span className="text-sm font-medium">Risk Level: </span>
                  <Badge className={cat.color}>{cat.risk}</Badge>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>

      {/* Important Notes */}
      <Card className="border-yellow-500/50 bg-yellow-500/5">
        <CardHeader>
          <div className="flex items-center gap-2">
            <AlertTriangle className="h-5 w-5 text-yellow-500" />
            <CardTitle>Important Notes</CardTitle>
          </div>
        </CardHeader>
        <CardContent className="space-y-2">
          <p className="text-sm text-muted-foreground">
            • <strong>Demo First:</strong> Always test EAs on a demo account before using real money.
          </p>
          <p className="text-sm text-muted-foreground">
            • <strong>Risk Management:</strong> Never risk more than you can afford to lose.
          </p>
          <p className="text-sm text-muted-foreground">
            • <strong>Martingale Warning:</strong> Martingale strategies can lead to significant losses. Use with extreme caution.
          </p>
          <p className="text-sm text-muted-foreground">
            • <strong>VPS Recommended:</strong> For 24/7 trading, use a VPS (Virtual Private Server).
          </p>
          <p className="text-sm text-muted-foreground">
            • <strong>Keep Updated:</strong> Check for EA updates regularly for bug fixes and improvements.
          </p>
        </CardContent>
      </Card>

      {/* Support */}
      <Card>
        <CardHeader>
          <div className="flex items-center gap-2">
            <Shield className="h-5 w-5 text-primary" />
            <CardTitle>Need Help?</CardTitle>
          </div>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-muted-foreground mb-4">
            If you encounter any issues or have questions, check your validation logs or contact support.
          </p>
          <div className="flex gap-2">
            <Link href="/settings">
              <Button variant="outline" size="sm">
                <Settings className="mr-2 h-4 w-4" />
                Settings
              </Button>
            </Link>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
