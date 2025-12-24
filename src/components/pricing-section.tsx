"use client"

import { useState } from "react"
import Link from "next/link"
import { Check, Sparkles } from "lucide-react"

const pricingTiers = [
    {
        name: "Starter",
        tier: "TIER_1",
        description: "Perfect for getting started",
        monthlyPrice: 29,
        accounts: 1,
        features: [
            "Access to all EAs",
            "1 MT account",
            "Basic analytics",
            "Email support",
        ],
        cta: "Start free trial",
        popular: false,
    },
    {
        name: "Trader",
        tier: "TIER_2",
        description: "For serious traders",
        monthlyPrice: 49,
        accounts: 5,
        features: [
            "Access to all EAs",
            "5 MT accounts",
            "Advanced analytics",
            "Priority support",
            "API access",
        ],
        cta: "Get started",
        popular: true,
    },
    {
        name: "Investor",
        tier: "TIER_3",
        description: "For professional traders",
        monthlyPrice: 99,
        accounts: 10,
        features: [
            "Access to all EAs",
            "10 MT accounts",
            "Full analytics suite",
            "VIP support",
            "API access",
            "Custom integrations",
        ],
        cta: "Contact sales",
        popular: false,
    },
]

export function PricingSection() {
    const [isYearly, setIsYearly] = useState(false)

    const getPrice = (monthlyPrice: number) => {
        if (isYearly) {
            // 2 months free = pay for 10 months
            return monthlyPrice * 10
        }
        return monthlyPrice
    }

    const getSavings = (monthlyPrice: number) => {
        // Savings = 2 months worth
        return monthlyPrice * 2
    }

    return (
        <section className="px-6 py-24 lg:px-12 bg-white border-y-[3px] border-[#1a1a1a]">
            <div className="max-w-6xl mx-auto">
                <div className="text-center mb-12">
                    <span className="inline-block px-4 py-2 text-sm font-bold bg-[#dcfce7] text-[#16a34a] border-[3px] border-[#1a1a1a] shadow-[4px_4px_0px_0px_#1a1a1a] mb-6">
                        SIMPLE PRICING
                    </span>
                    <h2 className="text-4xl lg:text-5xl font-black">Choose your plan</h2>
                    <p className="mt-4 text-lg text-[#6a6a6a]">Start with a 14-day free trial. No credit card required.</p>

                    {/* Toggle */}
                    <div className="flex items-center justify-center gap-4 mt-8">
                        <span className={`font-semibold ${!isYearly ? 'text-[#1a1a1a]' : 'text-[#6a6a6a]'}`}>
                            Monthly
                        </span>
                        <button
                            onClick={() => setIsYearly(!isYearly)}
                            className={`relative w-16 h-8 rounded-none border-[3px] border-[#1a1a1a] transition-colors ${isYearly ? 'bg-[#16a34a]' : 'bg-[#e5e5e5]'
                                }`}
                        >
                            <span
                                className={`absolute top-0.5 w-6 h-6 bg-white border-[2px] border-[#1a1a1a] transition-transform ${isYearly ? 'translate-x-8' : 'translate-x-0.5'
                                    }`}
                            />
                        </button>
                        <span className={`font-semibold ${isYearly ? 'text-[#1a1a1a]' : 'text-[#6a6a6a]'}`}>
                            Yearly
                        </span>
                        {isYearly && (
                            <span className="px-3 py-1 text-sm font-bold bg-[#fef9c3] text-[#1a1a1a] border-[2px] border-[#1a1a1a]">
                                2 months FREE
                            </span>
                        )}
                    </div>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                    {pricingTiers.map((tier) => (
                        <div
                            key={tier.name}
                            className={`relative p-8 border-[3px] border-[#1a1a1a] ${tier.popular
                                ? 'bg-[#16a34a] text-white shadow-[8px_8px_0px_0px_#1a1a1a]'
                                : 'bg-[#f5f5f5] shadow-[4px_4px_0px_0px_#1a1a1a]'
                                }`}
                        >
                            {tier.popular && (
                                <div className="absolute -top-4 left-1/2 -translate-x-1/2 px-4 py-1 bg-[#fbbf24] text-[#1a1a1a] font-bold text-sm border-[2px] border-[#1a1a1a] flex items-center gap-1">
                                    <Sparkles className="h-4 w-4" />
                                    MOST POPULAR
                                </div>
                            )}

                            <h3 className="text-2xl font-bold mb-2">{tier.name}</h3>
                            <p className={tier.popular ? 'text-white/80 mb-6' : 'text-[#6a6a6a] mb-6'}>
                                {tier.description}
                            </p>

                            <div className="mb-6">
                                <span className="text-4xl font-black">
                                    ${getPrice(tier.monthlyPrice)}
                                </span>
                                <span className={tier.popular ? 'text-white/80' : 'text-[#6a6a6a]'}>
                                    /{isYearly ? 'year' : 'month'}
                                </span>
                                {isYearly && (
                                    <div className={`text-sm mt-1 ${tier.popular ? 'text-white/70' : 'text-[#16a34a]'}`}>
                                        Save ${getSavings(tier.monthlyPrice)}/year
                                    </div>
                                )}
                            </div>

                            <ul className="space-y-3 mb-8">
                                {tier.features.map((feature) => (
                                    <li key={feature} className="flex items-center gap-2 font-medium">
                                        <Check className={`h-5 w-5 ${tier.popular ? 'text-[#fbbf24]' : 'text-[#16a34a]'}`} />
                                        {feature}
                                    </li>
                                ))}
                            </ul>

                            <Link
                                href="/register"
                                className={`block w-full py-3 text-center font-bold border-[3px] border-[#1a1a1a] shadow-[4px_4px_0px_0px_#1a1a1a] hover:shadow-[2px_2px_0px_0px_#1a1a1a] hover:translate-x-[2px] hover:translate-y-[2px] transition-all ${tier.popular
                                    ? 'bg-white text-[#16a34a]'
                                    : 'bg-white text-[#1a1a1a]'
                                    }`}
                            >
                                {tier.cta}
                            </Link>
                        </div>
                    ))}
                </div>

                <p className="text-center mt-8 text-[#6a6a6a] font-medium">
                    All plans include a 14-day free trial. No credit card required.
                </p>
            </div>
        </section>
    )
}
