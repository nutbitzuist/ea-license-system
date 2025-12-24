import * as React from "react"
import { Slot } from "@radix-ui/react-slot"
import { cva, type VariantProps } from "class-variance-authority"

import { cn } from "@/lib/utils"

const buttonVariants = cva(
  "inline-flex items-center justify-center gap-2 whitespace-nowrap text-sm font-bold transition-all focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:size-4 [&_svg]:shrink-0",
  {
    variants: {
      variant: {
        default:
          "bg-[var(--brutal-green)] text-white border-[3px] border-[var(--brutal-border)] brutal-shadow hover:brutal-shadow-sm hover:translate-x-[2px] hover:translate-y-[2px]",
        destructive:
          "bg-destructive text-destructive-foreground border-[3px] border-[var(--brutal-border)] brutal-shadow hover:brutal-shadow-sm hover:translate-x-[2px] hover:translate-y-[2px]",
        outline:
          "border-[3px] border-[var(--brutal-border)] bg-background brutal-shadow hover:brutal-shadow-sm hover:translate-x-[2px] hover:translate-y-[2px] hover:bg-[var(--brutal-green-light)]",
        secondary:
          "bg-secondary text-secondary-foreground border-[3px] border-[var(--brutal-border)] brutal-shadow hover:brutal-shadow-sm hover:translate-x-[2px] hover:translate-y-[2px]",
        ghost: "hover:bg-[var(--brutal-green-light)] hover:text-foreground",
        link: "text-[var(--brutal-green)] underline-offset-4 hover:underline",
      },
      size: {
        default: "h-10 px-5 py-2",
        sm: "h-9 px-4 text-xs",
        lg: "h-12 px-8 text-base",
        icon: "h-10 w-10",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  }
)

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
  VariantProps<typeof buttonVariants> {
  asChild?: boolean
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, asChild = false, ...props }, ref) => {
    const Comp = asChild ? Slot : "button"
    return (
      <Comp
        className={cn(buttonVariants({ variant, size, className }))}
        ref={ref}
        {...props}
      />
    )
  }
)
Button.displayName = "Button"

export { Button, buttonVariants }
