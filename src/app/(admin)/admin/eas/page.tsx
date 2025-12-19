"use client"

import { useState } from "react"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { Switch } from "@/components/ui/switch"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog"
import { Plus, Loader2, Edit, Bot } from "lucide-react"
import { useToast } from "@/hooks/use-toast"

interface ExpertAdvisor {
  id: string
  eaCode: string
  name: string
  description: string | null
  currentVersion: string
  mt4FileName: string | null
  mt5FileName: string | null
  isActive: boolean
  createdAt: string
  _count: {
    userAccess: number
  }
}

export default function AdminEAsPage() {
  const [isAddOpen, setIsAddOpen] = useState(false)
  const [editEa, setEditEa] = useState<ExpertAdvisor | null>(null)
  const [formData, setFormData] = useState({
    eaCode: "",
    name: "",
    description: "",
    currentVersion: "1.0.0",
  })
  const { toast } = useToast()
  const queryClient = useQueryClient()

  const { data, isLoading } = useQuery({
    queryKey: ["admin-eas"],
    queryFn: async () => {
      const res = await fetch("/api/admin/eas")
      if (!res.ok) throw new Error("Failed to fetch EAs")
      return res.json()
    },
  })

  const createMutation = useMutation({
    mutationFn: async (data: typeof formData) => {
      const res = await fetch("/api/admin/eas", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data),
      })
      if (!res.ok) {
        const error = await res.json()
        throw new Error(error.error || "Failed to create EA")
      }
      return res.json()
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-eas"] })
      setIsAddOpen(false)
      resetForm()
      toast({ title: "Success", description: "EA created successfully" })
    },
    onError: (error: Error) => {
      toast({ title: "Error", description: error.message, variant: "destructive" })
    },
  })

  const updateMutation = useMutation({
    mutationFn: async ({ id, data }: { id: string; data: Partial<ExpertAdvisor> }) => {
      const res = await fetch(`/api/admin/eas/${id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data),
      })
      if (!res.ok) throw new Error("Failed to update EA")
      return res.json()
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-eas"] })
      setEditEa(null)
      toast({ title: "Success", description: "EA updated successfully" })
    },
    onError: () => {
      toast({ title: "Error", description: "Failed to update EA", variant: "destructive" })
    },
  })

  const resetForm = () => {
    setFormData({
      eaCode: "",
      name: "",
      description: "",
      currentVersion: "1.0.0",
    })
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    createMutation.mutate(formData)
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Expert Advisors</h2>
          <p className="text-muted-foreground">
            Manage Expert Advisors and their files
          </p>
        </div>
        <Dialog open={isAddOpen} onOpenChange={setIsAddOpen}>
          <DialogTrigger asChild>
            <Button>
              <Plus className="mr-2 h-4 w-4" />
              Add EA
            </Button>
          </DialogTrigger>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>Add Expert Advisor</DialogTitle>
              <DialogDescription>
                Create a new Expert Advisor entry
              </DialogDescription>
            </DialogHeader>
            <form onSubmit={handleSubmit}>
              <div className="space-y-4 py-4">
                <div className="space-y-2">
                  <Label htmlFor="eaCode">EA Code</Label>
                  <Input
                    id="eaCode"
                    value={formData.eaCode}
                    onChange={(e) => setFormData({ ...formData, eaCode: e.target.value.toLowerCase().replace(/[^a-z0-9_]/g, "_") })}
                    placeholder="scalper_pro_v1"
                    required
                  />
                  <p className="text-xs text-muted-foreground">
                    Lowercase alphanumeric with underscores only
                  </p>
                </div>
                <div className="space-y-2">
                  <Label htmlFor="name">Name</Label>
                  <Input
                    id="name"
                    value={formData.name}
                    onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                    placeholder="Scalper Pro"
                    required
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="description">Description</Label>
                  <Textarea
                    id="description"
                    value={formData.description}
                    onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                    placeholder="A professional scalping EA..."
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="version">Version</Label>
                  <Input
                    id="version"
                    value={formData.currentVersion}
                    onChange={(e) => setFormData({ ...formData, currentVersion: e.target.value })}
                    placeholder="1.0.0"
                    required
                  />
                </div>
              </div>
              <DialogFooter>
                <Button type="button" variant="outline" onClick={() => setIsAddOpen(false)}>
                  Cancel
                </Button>
                <Button type="submit" disabled={createMutation.isPending}>
                  {createMutation.isPending && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                  Create EA
                </Button>
              </DialogFooter>
            </form>
          </DialogContent>
        </Dialog>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>All Expert Advisors</CardTitle>
          <CardDescription>Manage EA entries and their settings</CardDescription>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <div className="flex items-center justify-center py-8">
              <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
            </div>
          ) : data?.eas?.length > 0 ? (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>EA</TableHead>
                  <TableHead>Code</TableHead>
                  <TableHead>Version</TableHead>
                  <TableHead>Files</TableHead>
                  <TableHead>Users</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {data.eas.map((ea: ExpertAdvisor) => (
                  <TableRow key={ea.id}>
                    <TableCell>
                      <div className="flex items-center gap-3">
                        <div className="rounded-lg bg-primary/10 p-2">
                          <Bot className="h-4 w-4 text-primary" />
                        </div>
                        <div>
                          <p className="font-medium">{ea.name}</p>
                          {ea.description && (
                            <p className="text-sm text-muted-foreground line-clamp-1">
                              {ea.description}
                            </p>
                          )}
                        </div>
                      </div>
                    </TableCell>
                    <TableCell className="font-mono text-sm">{ea.eaCode}</TableCell>
                    <TableCell>v{ea.currentVersion}</TableCell>
                    <TableCell>
                      <div className="flex gap-1">
                        {ea.mt4FileName && <Badge variant="secondary">MT4</Badge>}
                        {ea.mt5FileName && <Badge variant="secondary">MT5</Badge>}
                        {!ea.mt4FileName && !ea.mt5FileName && (
                          <span className="text-muted-foreground text-sm">None</span>
                        )}
                      </div>
                    </TableCell>
                    <TableCell>{ea._count.userAccess}</TableCell>
                    <TableCell>
                      <Switch
                        checked={ea.isActive}
                        onCheckedChange={(checked) =>
                          updateMutation.mutate({ id: ea.id, data: { isActive: checked } })
                        }
                      />
                    </TableCell>
                    <TableCell className="text-right">
                      <Button
                        variant="ghost"
                        size="icon"
                        onClick={() => setEditEa(ea)}
                      >
                        <Edit className="h-4 w-4" />
                      </Button>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          ) : (
            <div className="text-center py-8">
              <Bot className="h-12 w-12 text-muted-foreground mx-auto mb-4" />
              <p className="text-muted-foreground">No Expert Advisors created yet</p>
              <Button className="mt-4" onClick={() => setIsAddOpen(true)}>
                <Plus className="mr-2 h-4 w-4" />
                Create Your First EA
              </Button>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Edit EA Dialog */}
      <Dialog open={!!editEa} onOpenChange={(open) => !open && setEditEa(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Edit Expert Advisor</DialogTitle>
            <DialogDescription>Update EA details</DialogDescription>
          </DialogHeader>
          {editEa && (
            <div className="space-y-4 py-4">
              <div className="space-y-2">
                <Label>Name</Label>
                <Input
                  value={editEa.name}
                  onChange={(e) => setEditEa({ ...editEa, name: e.target.value })}
                />
              </div>
              <div className="space-y-2">
                <Label>Description</Label>
                <Textarea
                  value={editEa.description || ""}
                  onChange={(e) => setEditEa({ ...editEa, description: e.target.value })}
                />
              </div>
              <div className="space-y-2">
                <Label>Version</Label>
                <Input
                  value={editEa.currentVersion}
                  onChange={(e) => setEditEa({ ...editEa, currentVersion: e.target.value })}
                />
              </div>
            </div>
          )}
          <DialogFooter>
            <Button variant="outline" onClick={() => setEditEa(null)}>
              Cancel
            </Button>
            <Button
              onClick={() => {
                if (editEa) {
                  updateMutation.mutate({
                    id: editEa.id,
                    data: {
                      name: editEa.name,
                      description: editEa.description,
                      currentVersion: editEa.currentVersion,
                    },
                  })
                }
              }}
              disabled={updateMutation.isPending}
            >
              {updateMutation.isPending && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
              Save Changes
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
