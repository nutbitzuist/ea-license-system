"use client"

import { useState } from "react"
import { useQuery } from "@tanstack/react-query"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Download, Bot, Loader2, Search, Package, AlertTriangle, Wrench, TrendingUp } from "lucide-react"
import { useToast } from "@/hooks/use-toast"

interface ExpertAdvisor {
  id: string
  eaCode: string
  name: string
  description: string | null
  currentVersion: string
  isActive: boolean
  expiresAt: string | null
}

type Category = "all" | "basic" | "advanced" | "martingale" | "utility"

const categoryInfo: Record<Category, { label: string; icon: React.ElementType; description: string }> = {
  all: { label: "All EAs", icon: Package, description: "All available Expert Advisors" },
  basic: { label: "Basic Strategies", icon: TrendingUp, description: "Fundamental trading strategies (1-10)" },
  advanced: { label: "Advanced Strategies", icon: Bot, description: "Sophisticated trading systems (11-20)" },
  martingale: { label: "Martingale", icon: AlertTriangle, description: "High-risk martingale strategies (21-30)" },
  utility: { label: "Utilities & Tools", icon: Wrench, description: "Trading utilities and helpers (31-40)" },
}

function getCategory(eaCode: string): Category {
  const code = eaCode.toLowerCase()
  if (code.includes("martingale") || code.includes("dalembert") || code.includes("labouchere") || 
      code.includes("parlay") || code.includes("oscar") || code.includes("hybrid_martingale")) {
    return "martingale"
  }
  if (code.includes("manager") || code.includes("calculator") || code.includes("protector") ||
      code.includes("monitor") || code.includes("copier") || code.includes("session") ||
      code.includes("block") || code.includes("journal") || code.includes("news_filter_utility")) {
    return "utility"
  }
  // Advanced EAs (11-20)
  if (code.includes("multi_timeframe") || code.includes("fibonacci_retracement") || 
      code.includes("price_action") || code.includes("momentum") || code.includes("london") ||
      code.includes("mean_reversion") || code.includes("keltner") || code.includes("williams") ||
      code.includes("parabolic") || code.includes("hedge")) {
    return "advanced"
  }
  return "basic"
}

export default function DownloadsPage() {
  const { toast } = useToast()
  const [searchQuery, setSearchQuery] = useState("")
  const [activeCategory, setActiveCategory] = useState<Category>("all")
  const [downloadingEAs, setDownloadingEAs] = useState<Set<string>>(new Set())

  const { data, isLoading } = useQuery({
    queryKey: ["user-eas"],
    queryFn: async () => {
      const res = await fetch("/api/eas")
      if (!res.ok) throw new Error("Failed to fetch EAs")
      return res.json()
    },
  })

  const handleDownload = async (eaCode: string, terminal: "MT4" | "MT5") => {
    const key = `${eaCode}-${terminal}`
    setDownloadingEAs(prev => new Set(prev).add(key))
    
    try {
      const res = await fetch(`/api/eas/${eaCode}/download?terminal=${terminal}`)
      if (!res.ok) {
        const error = await res.json()
        throw new Error(error.error || "Download failed")
      }
      
      const blob = await res.blob()
      const url = window.URL.createObjectURL(blob)
      const a = document.createElement("a")
      a.href = url
      a.download = `${eaCode}.mq${terminal === "MT4" ? "4" : "5"}`
      document.body.appendChild(a)
      a.click()
      window.URL.revokeObjectURL(url)
      document.body.removeChild(a)
      
      toast({ title: "Success", description: `${eaCode} (${terminal}) downloaded` })
    } catch (error) {
      toast({
        title: "Error",
        description: error instanceof Error ? error.message : "Download failed",
        variant: "destructive",
      })
    } finally {
      setDownloadingEAs(prev => {
        const next = new Set(prev)
        next.delete(key)
        return next
      })
    }
  }

  const handleDownloadAll = async (terminal: "MT4" | "MT5") => {
    if (!data?.eas) return
    
    toast({ title: "Starting downloads", description: `Downloading all ${terminal} files...` })
    
    for (const ea of data.eas) {
      await handleDownload(ea.eaCode, terminal)
      // Small delay between downloads
      await new Promise(resolve => setTimeout(resolve, 500))
    }
    
    toast({ title: "Complete", description: `All ${terminal} files downloaded` })
  }

  const filteredEAs = data?.eas?.filter((ea: ExpertAdvisor) => {
    const matchesSearch = ea.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
                         ea.eaCode.toLowerCase().includes(searchQuery.toLowerCase()) ||
                         ea.description?.toLowerCase().includes(searchQuery.toLowerCase())
    const matchesCategory = activeCategory === "all" || getCategory(ea.eaCode) === activeCategory
    return matchesSearch && matchesCategory
  }) || []

  const categoryCounts = data?.eas?.reduce((acc: Record<Category, number>, ea: ExpertAdvisor) => {
    const cat = getCategory(ea.eaCode)
    acc[cat] = (acc[cat] || 0) + 1
    acc.all = (acc.all || 0) + 1
    return acc
  }, { all: 0, basic: 0, advanced: 0, martingale: 0, utility: 0 } as Record<Category, number>) || {}

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Downloads</h2>
          <p className="text-muted-foreground">
            Download Expert Advisors for MT4 and MT5
          </p>
        </div>
        <div className="flex gap-2">
          <Button onClick={() => handleDownloadAll("MT4")} variant="outline">
            <Download className="mr-2 h-4 w-4" />
            Download All MT4
          </Button>
          <Button onClick={() => handleDownloadAll("MT5")} variant="outline">
            <Download className="mr-2 h-4 w-4" />
            Download All MT5
          </Button>
        </div>
      </div>

      {/* Search */}
      <div className="relative">
        <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
        <Input
          placeholder="Search Expert Advisors..."
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          className="pl-10"
        />
      </div>

      {/* Category Tabs */}
      <Tabs value={activeCategory} onValueChange={(v) => setActiveCategory(v as Category)}>
        <TabsList className="grid w-full grid-cols-5">
          {(Object.keys(categoryInfo) as Category[]).map((cat) => {
            const Icon = categoryInfo[cat].icon
            return (
              <TabsTrigger key={cat} value={cat} className="flex items-center gap-2">
                <Icon className="h-4 w-4" />
                <span className="hidden sm:inline">{categoryInfo[cat].label}</span>
                <Badge variant="secondary" className="ml-1">{categoryCounts[cat] || 0}</Badge>
              </TabsTrigger>
            )
          })}
        </TabsList>

        <TabsContent value={activeCategory} className="mt-6">
          <div className="mb-4">
            <p className="text-sm text-muted-foreground">{categoryInfo[activeCategory].description}</p>
          </div>

          {isLoading ? (
            <div className="flex items-center justify-center py-12">
              <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
            </div>
          ) : filteredEAs.length > 0 ? (
            <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
              {filteredEAs.map((ea: ExpertAdvisor) => {
                const category = getCategory(ea.eaCode)
                const CategoryIcon = categoryInfo[category].icon
                
                return (
                  <Card key={ea.id} className="flex flex-col">
                    <CardHeader className="pb-3">
                      <div className="flex items-start justify-between">
                        <div className="flex items-center gap-3">
                          <div className={`rounded-lg p-2 ${
                            category === "martingale" ? "bg-destructive/10" :
                            category === "utility" ? "bg-blue-500/10" :
                            category === "advanced" ? "bg-purple-500/10" :
                            "bg-primary/10"
                          }`}>
                            <CategoryIcon className={`h-5 w-5 ${
                              category === "martingale" ? "text-destructive" :
                              category === "utility" ? "text-blue-500" :
                              category === "advanced" ? "text-purple-500" :
                              "text-primary"
                            }`} />
                          </div>
                          <div>
                            <CardTitle className="text-base">{ea.name}</CardTitle>
                            <CardDescription className="text-xs">{ea.eaCode}</CardDescription>
                          </div>
                        </div>
                        <Badge variant="outline" className="text-xs">v{ea.currentVersion}</Badge>
                      </div>
                    </CardHeader>
                    <CardContent className="flex-1 flex flex-col justify-between gap-4">
                      {ea.description && (
                        <p className="text-sm text-muted-foreground line-clamp-2">{ea.description}</p>
                      )}
                      <div className="flex gap-2">
                        <Button
                          variant="outline"
                          size="sm"
                          className="flex-1"
                          onClick={() => handleDownload(ea.eaCode, "MT4")}
                          disabled={downloadingEAs.has(`${ea.eaCode}-MT4`)}
                        >
                          {downloadingEAs.has(`${ea.eaCode}-MT4`) ? (
                            <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                          ) : (
                            <Download className="mr-2 h-4 w-4" />
                          )}
                          MT4
                        </Button>
                        <Button
                          variant="outline"
                          size="sm"
                          className="flex-1"
                          onClick={() => handleDownload(ea.eaCode, "MT5")}
                          disabled={downloadingEAs.has(`${ea.eaCode}-MT5`)}
                        >
                          {downloadingEAs.has(`${ea.eaCode}-MT5`) ? (
                            <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                          ) : (
                            <Download className="mr-2 h-4 w-4" />
                          )}
                          MT5
                        </Button>
                      </div>
                    </CardContent>
                  </Card>
                )
              })}
            </div>
          ) : (
            <Card>
              <CardContent className="flex flex-col items-center justify-center py-12">
                <Bot className="h-12 w-12 text-muted-foreground mb-4" />
                <h3 className="text-lg font-semibold">No Expert Advisors Found</h3>
                <p className="text-muted-foreground text-center mt-2">
                  {searchQuery ? "Try a different search term" : "No EAs available in this category"}
                </p>
              </CardContent>
            </Card>
          )}
        </TabsContent>
      </Tabs>
    </div>
  )
}
