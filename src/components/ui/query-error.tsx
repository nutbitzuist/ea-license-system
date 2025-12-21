"use client"

import { AlertCircle, RefreshCw } from "lucide-react"
import { Button } from "./button"

interface QueryErrorProps {
    message?: string
    onRetry?: () => void
}

export function QueryError({
    message = "Failed to load data",
    onRetry,
}: QueryErrorProps) {
    return (
        <div className="flex flex-col items-center justify-center py-12 text-center">
            <AlertCircle className="h-12 w-12 text-red-500 mb-4" />
            <p className="text-lg font-medium text-red-500 mb-2">{message}</p>
            <p className="text-sm text-muted-foreground mb-4">
                Please check your connection and try again.
            </p>
            {onRetry && (
                <Button variant="outline" onClick={onRetry}>
                    <RefreshCw className="h-4 w-4 mr-2" /> Retry
                </Button>
            )}
        </div>
    )
}
