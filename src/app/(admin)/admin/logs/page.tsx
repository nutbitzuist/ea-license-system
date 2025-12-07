"use client"

import { useState } from "react"
import { useQuery } from "@tanstack/react-query"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Input } from "@/components/ui/input"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { Button } from "@/components/ui/button"
import { Search, Loader2, ChevronLeft, ChevronRight } from "lucide-react"

interface ValidationLog {
  id: string
  accountNumber: string
  brokerName: string
  terminalType: string
  eaCode: string
  eaVersion: string
  ipAddress: string | null
  result: "SUCCESS" | "FAILED"
  failureReason: string | null
  createdAt: string
  user: {
    name: string
    email: string
  }
}

export default function AdminLogsPage() {
  const [page, setPage] = useState(1)
  const [search, setSearch] = useState("")
  const [resultFilter, setResultFilter] = useState<string>("all")

  const { data, isLoading } = useQuery({
    queryKey: ["admin-logs", page, search, resultFilter],
    queryFn: async () => {
      const params = new URLSearchParams()
      params.set("page", page.toString())
      if (search) params.set("search", search)
      if (resultFilter !== "all") params.set("result", resultFilter)
      const res = await fetch(`/api/admin/logs?${params}`)
      if (!res.ok) throw new Error("Failed to fetch logs")
      return res.json()
    },
  })

  const totalPages = Math.ceil((data?.total || 0) / 20)

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-3xl font-bold tracking-tight">Validation Logs</h2>
        <p className="text-muted-foreground">
          View all license validation attempts
        </p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>All Logs</CardTitle>
          <CardDescription>
            {data?.total || 0} total validation attempts
          </CardDescription>
        </CardHeader>
        <CardContent>
          {/* Filters */}
          <div className="flex gap-4 mb-6">
            <div className="relative flex-1">
              <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
              <Input
                placeholder="Search by account, broker, or EA code..."
                value={search}
                onChange={(e) => {
                  setSearch(e.target.value)
                  setPage(1)
                }}
                className="pl-10"
              />
            </div>
            <Select
              value={resultFilter}
              onValueChange={(value) => {
                setResultFilter(value)
                setPage(1)
              }}
            >
              <SelectTrigger className="w-48">
                <SelectValue placeholder="Filter by result" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Results</SelectItem>
                <SelectItem value="SUCCESS">Success</SelectItem>
                <SelectItem value="FAILED">Failed</SelectItem>
              </SelectContent>
            </Select>
          </div>

          {/* Table */}
          {isLoading ? (
            <div className="flex items-center justify-center py-8">
              <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
            </div>
          ) : data?.logs?.length > 0 ? (
            <>
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Time</TableHead>
                    <TableHead>User</TableHead>
                    <TableHead>Account</TableHead>
                    <TableHead>Broker</TableHead>
                    <TableHead>EA</TableHead>
                    <TableHead>Terminal</TableHead>
                    <TableHead>Result</TableHead>
                    <TableHead>Reason</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {data.logs.map((log: ValidationLog) => (
                    <TableRow key={log.id}>
                      <TableCell className="whitespace-nowrap">
                        {new Date(log.createdAt).toLocaleString()}
                      </TableCell>
                      <TableCell>
                        <div>
                          <p className="font-medium">{log.user.name}</p>
                          <p className="text-xs text-muted-foreground">{log.user.email}</p>
                        </div>
                      </TableCell>
                      <TableCell className="font-mono">{log.accountNumber}</TableCell>
                      <TableCell>{log.brokerName}</TableCell>
                      <TableCell>
                        <div>
                          <p className="font-medium">{log.eaCode}</p>
                          <p className="text-xs text-muted-foreground">v{log.eaVersion}</p>
                        </div>
                      </TableCell>
                      <TableCell>{log.terminalType}</TableCell>
                      <TableCell>
                        <Badge variant={log.result === "SUCCESS" ? "success" : "destructive"}>
                          {log.result}
                        </Badge>
                      </TableCell>
                      <TableCell className="max-w-[200px] truncate">
                        {log.failureReason || "-"}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>

              {/* Pagination */}
              <div className="flex items-center justify-between mt-4">
                <p className="text-sm text-muted-foreground">
                  Page {page} of {totalPages}
                </p>
                <div className="flex gap-2">
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => setPage(page - 1)}
                    disabled={page <= 1}
                  >
                    <ChevronLeft className="h-4 w-4" />
                    Previous
                  </Button>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => setPage(page + 1)}
                    disabled={page >= totalPages}
                  >
                    Next
                    <ChevronRight className="h-4 w-4" />
                  </Button>
                </div>
              </div>
            </>
          ) : (
            <div className="text-center py-8">
              <p className="text-muted-foreground">No validation logs found</p>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
