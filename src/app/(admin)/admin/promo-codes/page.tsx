"use client"

import { useState } from "react"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog"
import { AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent, AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle, AlertDialogTrigger } from "@/components/ui/alert-dialog"
import { Plus, Loader2, Trash2, Pause, Play, Gift, Calendar, Users, Clock } from "lucide-react"
import { useToast } from "@/hooks/use-toast"

interface PromoCode {
    id: string
    code: string
    description: string | null
    daysGranted: number
    subscriptionTier: "TIER_1" | "TIER_2" | "TIER_3" | null
    maxUsages: number
    currentUsages: number
    isActive: boolean
    expiresAt: string | null
    createdAt: string
    _count: {
        usages: number
    }
}

const tierLabels: Record<string, string> = {
    TIER_1: "Beginner (1 acct)",
    TIER_2: "Trader (5 accts)",
    TIER_3: "Investor (10 accts)",
}

export default function AdminPromoCodesPage() {
    const { toast } = useToast()
    const queryClient = useQueryClient()
    const [isCreateOpen, setIsCreateOpen] = useState(false)
    const [newCode, setNewCode] = useState("")
    const [description, setDescription] = useState("")
    const [daysGranted, setDaysGranted] = useState("14")
    const [subscriptionTier, setSubscriptionTier] = useState<string>("")
    const [maxUsages, setMaxUsages] = useState("0")
    const [expiresAt, setExpiresAt] = useState("")

    const { data, isLoading } = useQuery({
        queryKey: ["admin-promo-codes"],
        queryFn: async () => {
            const res = await fetch("/api/admin/promo-codes")
            if (!res.ok) throw new Error("Failed to fetch promo codes")
            return res.json()
        },
    })

    const createMutation = useMutation({
        mutationFn: async (data: {
            code: string
            description?: string
            daysGranted: number
            subscriptionTier?: string | null
            maxUsages: number
            expiresAt?: string | null
        }) => {
            const res = await fetch("/api/admin/promo-codes", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify(data),
            })
            const result = await res.json()
            if (!res.ok) throw new Error(result.error || "Failed to create promo code")
            return result
        },
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ["admin-promo-codes"] })
            toast({ title: "Success", description: "Promo code created successfully" })
            resetForm()
            setIsCreateOpen(false)
        },
        onError: (error: Error) => {
            toast({ title: "Error", description: error.message, variant: "destructive" })
        },
    })

    const toggleMutation = useMutation({
        mutationFn: async ({ id, isActive }: { id: string; isActive: boolean }) => {
            const res = await fetch(`/api/admin/promo-codes?id=${id}`, {
                method: "PATCH",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ isActive }),
            })
            const result = await res.json()
            if (!res.ok) throw new Error(result.error || "Failed to update promo code")
            return result
        },
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ["admin-promo-codes"] })
            toast({ title: "Success", description: "Promo code updated" })
        },
        onError: (error: Error) => {
            toast({ title: "Error", description: error.message, variant: "destructive" })
        },
    })

    const deleteMutation = useMutation({
        mutationFn: async (id: string) => {
            const res = await fetch(`/api/admin/promo-codes?id=${id}`, {
                method: "DELETE",
            })
            const result = await res.json()
            if (!res.ok) throw new Error(result.error || "Failed to delete promo code")
            return result
        },
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ["admin-promo-codes"] })
            toast({ title: "Success", description: "Promo code deleted" })
        },
        onError: (error: Error) => {
            toast({ title: "Error", description: error.message, variant: "destructive" })
        },
    })

    const resetForm = () => {
        setNewCode("")
        setDescription("")
        setDaysGranted("14")
        setSubscriptionTier("")
        setMaxUsages("0")
        setExpiresAt("")
    }

    const handleCreate = (e: React.FormEvent) => {
        e.preventDefault()
        createMutation.mutate({
            code: newCode.toUpperCase(),
            description: description || undefined,
            daysGranted: parseInt(daysGranted) || 0,
            subscriptionTier: subscriptionTier || null,
            maxUsages: parseInt(maxUsages) || 0,
            expiresAt: expiresAt ? new Date(expiresAt).toISOString() : null,
        })
    }

    const isExpired = (expiresAt: string | null) => {
        if (!expiresAt) return false
        return new Date(expiresAt) < new Date()
    }

    const isMaxedOut = (promo: PromoCode) => {
        return promo.maxUsages > 0 && promo._count.usages >= promo.maxUsages
    }

    return (
        <div className="space-y-6">
            <div className="flex justify-between items-center">
                <div>
                    <h2 className="text-3xl font-bold tracking-tight">Promo Codes</h2>
                    <p className="text-muted-foreground">
                        Create and manage promotional codes for user registration
                    </p>
                </div>
                <Dialog open={isCreateOpen} onOpenChange={setIsCreateOpen}>
                    <DialogTrigger asChild>
                        <Button>
                            <Plus className="mr-2 h-4 w-4" />
                            Create Code
                        </Button>
                    </DialogTrigger>
                    <DialogContent className="max-w-md">
                        <DialogHeader>
                            <DialogTitle>Create Promo Code</DialogTitle>
                            <DialogDescription>
                                Create a promotional code for new user registrations.
                            </DialogDescription>
                        </DialogHeader>
                        <form onSubmit={handleCreate}>
                            <div className="space-y-4 py-4">
                                <div className="space-y-2">
                                    <Label htmlFor="code">Code *</Label>
                                    <Input
                                        id="code"
                                        placeholder="SUMMER2024"
                                        value={newCode}
                                        onChange={(e) => setNewCode(e.target.value.toUpperCase())}
                                        required
                                    />
                                </div>
                                <div className="space-y-2">
                                    <Label htmlFor="description">Description</Label>
                                    <Textarea
                                        id="description"
                                        placeholder="Summer promotion - 30 days free"
                                        value={description}
                                        onChange={(e) => setDescription(e.target.value)}
                                    />
                                </div>
                                <div className="grid grid-cols-2 gap-4">
                                    <div className="space-y-2">
                                        <Label htmlFor="days">Days Granted</Label>
                                        <Input
                                            id="days"
                                            type="number"
                                            min="0"
                                            value={daysGranted}
                                            onChange={(e) => setDaysGranted(e.target.value)}
                                        />
                                    </div>
                                    <div className="space-y-2">
                                        <Label htmlFor="maxUsages">Max Usages (0 = unlimited)</Label>
                                        <Input
                                            id="maxUsages"
                                            type="number"
                                            min="0"
                                            value={maxUsages}
                                            onChange={(e) => setMaxUsages(e.target.value)}
                                        />
                                    </div>
                                </div>
                                <div className="space-y-2">
                                    <Label htmlFor="tier">Upgrade to Tier (optional)</Label>
                                    <Select value={subscriptionTier} onValueChange={setSubscriptionTier}>
                                        <SelectTrigger id="tier">
                                            <SelectValue placeholder="No tier change" />
                                        </SelectTrigger>
                                        <SelectContent>
                                            <SelectItem value="">No tier change</SelectItem>
                                            <SelectItem value="TIER_1">Beginner (1 account)</SelectItem>
                                            <SelectItem value="TIER_2">Trader (5 accounts)</SelectItem>
                                            <SelectItem value="TIER_3">Investor (10 accounts)</SelectItem>
                                        </SelectContent>
                                    </Select>
                                </div>
                                <div className="space-y-2">
                                    <Label htmlFor="expires">Expires At (optional)</Label>
                                    <Input
                                        id="expires"
                                        type="datetime-local"
                                        value={expiresAt}
                                        onChange={(e) => setExpiresAt(e.target.value)}
                                    />
                                </div>
                            </div>
                            <DialogFooter>
                                <Button type="button" variant="outline" onClick={() => setIsCreateOpen(false)}>
                                    Cancel
                                </Button>
                                <Button type="submit" disabled={createMutation.isPending}>
                                    {createMutation.isPending && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                                    Create
                                </Button>
                            </DialogFooter>
                        </form>
                    </DialogContent>
                </Dialog>
            </div>

            <Card>
                <CardHeader>
                    <CardTitle className="flex items-center gap-2">
                        <Gift className="h-5 w-5" />
                        Active Promo Codes
                    </CardTitle>
                    <CardDescription>
                        Users can enter these codes during registration for special benefits
                    </CardDescription>
                </CardHeader>
                <CardContent>
                    {isLoading ? (
                        <div className="flex items-center justify-center py-8">
                            <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
                        </div>
                    ) : data?.promoCodes?.length > 0 ? (
                        <Table>
                            <TableHeader>
                                <TableRow>
                                    <TableHead>Code</TableHead>
                                    <TableHead>Benefits</TableHead>
                                    <TableHead>Usage</TableHead>
                                    <TableHead>Expires</TableHead>
                                    <TableHead>Status</TableHead>
                                    <TableHead className="text-right">Actions</TableHead>
                                </TableRow>
                            </TableHeader>
                            <TableBody>
                                {data.promoCodes.map((promo: PromoCode) => (
                                    <TableRow key={promo.id}>
                                        <TableCell>
                                            <div>
                                                <code className="font-mono font-bold text-primary">{promo.code}</code>
                                                {promo.description && (
                                                    <p className="text-xs text-muted-foreground mt-1">{promo.description}</p>
                                                )}
                                            </div>
                                        </TableCell>
                                        <TableCell>
                                            <div className="flex flex-col gap-1">
                                                {promo.daysGranted > 0 && (
                                                    <Badge variant="outline" className="w-fit">
                                                        <Calendar className="h-3 w-3 mr-1" />
                                                        +{promo.daysGranted} days
                                                    </Badge>
                                                )}
                                                {promo.subscriptionTier && (
                                                    <Badge variant="secondary" className="w-fit">
                                                        {tierLabels[promo.subscriptionTier]}
                                                    </Badge>
                                                )}
                                            </div>
                                        </TableCell>
                                        <TableCell>
                                            <div className="flex items-center gap-1">
                                                <Users className="h-4 w-4 text-muted-foreground" />
                                                <span>
                                                    {promo._count.usages}
                                                    {promo.maxUsages > 0 && ` / ${promo.maxUsages}`}
                                                </span>
                                            </div>
                                        </TableCell>
                                        <TableCell>
                                            {promo.expiresAt ? (
                                                <div className="flex items-center gap-1">
                                                    <Clock className="h-4 w-4 text-muted-foreground" />
                                                    <span className={isExpired(promo.expiresAt) ? "text-destructive" : ""}>
                                                        {new Date(promo.expiresAt).toLocaleDateString()}
                                                    </span>
                                                </div>
                                            ) : (
                                                <span className="text-muted-foreground">Never</span>
                                            )}
                                        </TableCell>
                                        <TableCell>
                                            {isExpired(promo.expiresAt) ? (
                                                <Badge variant="destructive">Expired</Badge>
                                            ) : isMaxedOut(promo) ? (
                                                <Badge variant="secondary">Maxed Out</Badge>
                                            ) : promo.isActive ? (
                                                <Badge variant="success">Active</Badge>
                                            ) : (
                                                <Badge variant="warning">Paused</Badge>
                                            )}
                                        </TableCell>
                                        <TableCell className="text-right">
                                            <div className="flex justify-end gap-2">
                                                <Button
                                                    variant="ghost"
                                                    size="icon"
                                                    onClick={() => toggleMutation.mutate({ id: promo.id, isActive: !promo.isActive })}
                                                    title={promo.isActive ? "Pause" : "Activate"}
                                                >
                                                    {promo.isActive ? (
                                                        <Pause className="h-4 w-4 text-yellow-500" />
                                                    ) : (
                                                        <Play className="h-4 w-4 text-green-500" />
                                                    )}
                                                </Button>
                                                <AlertDialog>
                                                    <AlertDialogTrigger asChild>
                                                        <Button variant="ghost" size="icon" title="Delete">
                                                            <Trash2 className="h-4 w-4 text-destructive" />
                                                        </Button>
                                                    </AlertDialogTrigger>
                                                    <AlertDialogContent>
                                                        <AlertDialogHeader>
                                                            <AlertDialogTitle>Delete Promo Code</AlertDialogTitle>
                                                            <AlertDialogDescription>
                                                                Are you sure you want to delete the code &quot;{promo.code}&quot;?
                                                                This action cannot be undone.
                                                            </AlertDialogDescription>
                                                        </AlertDialogHeader>
                                                        <AlertDialogFooter>
                                                            <AlertDialogCancel>Cancel</AlertDialogCancel>
                                                            <AlertDialogAction
                                                                onClick={() => deleteMutation.mutate(promo.id)}
                                                                className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
                                                            >
                                                                Delete
                                                            </AlertDialogAction>
                                                        </AlertDialogFooter>
                                                    </AlertDialogContent>
                                                </AlertDialog>
                                            </div>
                                        </TableCell>
                                    </TableRow>
                                ))}
                            </TableBody>
                        </Table>
                    ) : (
                        <div className="text-center py-8">
                            <Gift className="h-12 w-12 mx-auto mb-4 text-muted-foreground opacity-50" />
                            <p className="text-muted-foreground">No promo codes yet</p>
                            <p className="text-sm text-muted-foreground">Create your first code to get started</p>
                        </div>
                    )}
                </CardContent>
            </Card>
        </div>
    )
}
