import { Card, CardContent, CardHeader } from "@/components/ui/card"

function SkeletonPulse({ className }: { className?: string }) {
    return (
        <div className={`animate-pulse bg-muted rounded ${className || ""}`} />
    )
}

export default function DashboardLoading() {
    return (
        <div className="space-y-6">
            {/* Header skeleton */}
            <div>
                <SkeletonPulse className="h-8 w-48 mb-2" />
                <SkeletonPulse className="h-4 w-64" />
            </div>

            {/* Status banner skeleton */}
            <Card>
                <CardContent className="flex items-center gap-4 py-4">
                    <SkeletonPulse className="h-5 w-5 rounded-full" />
                    <div className="flex-1">
                        <SkeletonPulse className="h-4 w-48 mb-2" />
                        <SkeletonPulse className="h-3 w-72" />
                    </div>
                </CardContent>
            </Card>

            {/* Stats grid skeleton */}
            <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
                {[1, 2, 3, 4].map((i) => (
                    <Card key={i}>
                        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                            <SkeletonPulse className="h-4 w-24" />
                            <SkeletonPulse className="h-4 w-4" />
                        </CardHeader>
                        <CardContent>
                            <SkeletonPulse className="h-8 w-16 mb-1" />
                            <SkeletonPulse className="h-3 w-20" />
                        </CardContent>
                    </Card>
                ))}
            </div>

            {/* Recent validations skeleton */}
            <Card>
                <CardHeader>
                    <SkeletonPulse className="h-5 w-40 mb-2" />
                    <SkeletonPulse className="h-4 w-64" />
                </CardHeader>
                <CardContent>
                    <div className="space-y-4">
                        {[1, 2, 3].map((i) => (
                            <div key={i} className="flex items-center justify-between border-b pb-4 last:border-0">
                                <div>
                                    <SkeletonPulse className="h-4 w-32 mb-2" />
                                    <SkeletonPulse className="h-3 w-24" />
                                </div>
                                <div className="text-right">
                                    <SkeletonPulse className="h-5 w-16 mb-1" />
                                    <SkeletonPulse className="h-3 w-24" />
                                </div>
                            </div>
                        ))}
                    </div>
                </CardContent>
            </Card>
        </div>
    )
}
