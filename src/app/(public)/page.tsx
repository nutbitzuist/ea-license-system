import Link from "next/link"
import { Layers, Bot, Key, Activity, ArrowRight, Globe, Lock, Star, TrendingUp, BarChart3, Users, Check, X, Sparkles, Timer, ChevronRight } from "lucide-react"

export default function LandingPage() {
    return (
        <div className="bg-[#f5f5f5] text-[#1a1a1a] min-h-screen">
            {/* Navigation */}
            <nav className="sticky top-0 z-50 flex items-center justify-between px-6 py-4 lg:px-12 bg-[#f5f5f5] border-b-[3px] border-[#1a1a1a]">
                <Link href="/" className="flex items-center gap-3 group">
                    <div className="w-10 h-10 bg-[#16a34a] border-[3px] border-[#1a1a1a] flex items-center justify-center shadow-[4px_4px_0px_0px_#1a1a1a] group-hover:shadow-[2px_2px_0px_0px_#1a1a1a] group-hover:translate-x-[2px] group-hover:translate-y-[2px] transition-all">
                        <Layers className="h-5 w-5 text-white" />
                    </div>
                    <span className="text-xl font-bold tracking-tight">My Algo Stack</span>
                </Link>

                <div className="flex items-center gap-3">
                    <Link href="/login" className="px-5 py-2.5 text-sm font-semibold hover:underline underline-offset-4">
                        Login
                    </Link>
                    <Link
                        href="/register"
                        className="px-5 py-2.5 text-sm font-bold bg-[#16a34a] text-white border-[3px] border-[#1a1a1a] shadow-[4px_4px_0px_0px_#1a1a1a] hover:shadow-[2px_2px_0px_0px_#1a1a1a] hover:translate-x-[2px] hover:translate-y-[2px] transition-all"
                    >
                        Start Free Trial
                    </Link>
                </div>
            </nav>

            {/* Hero Section */}
            <section className="px-6 pt-16 pb-24 lg:px-12 lg:pt-24 lg:pb-32">
                <div className="max-w-7xl mx-auto">
                    <div className="flex flex-col lg:flex-row lg:items-center lg:gap-16">
                        {/* Left content */}
                        <div className="flex-1">
                            <div className="inline-flex items-center gap-2 px-4 py-2 mb-8 text-sm font-bold bg-[#dcfce7] border-[3px] border-[#1a1a1a] shadow-[4px_4px_0px_0px_#1a1a1a]">
                                <Sparkles className="h-4 w-4 text-[#16a34a]" />
                                <span>500+ traders already automated</span>
                            </div>

                            <h1 className="text-5xl lg:text-7xl font-black leading-[1.05] tracking-tight">
                                Stop manual trading.
                                <br />
                                <span className="text-[#16a34a]">
                                    Start winning.
                                </span>
                            </h1>

                            <p className="mt-8 text-lg lg:text-xl text-[#4a4a4a] max-w-lg leading-relaxed font-medium">
                                40+ battle-tested Expert Advisors with enterprise-grade license management.
                                Deploy in minutes. Control everything.
                            </p>

                            <div className="flex flex-col sm:flex-row items-start sm:items-center gap-4 mt-10">
                                <Link
                                    href="/register"
                                    className="group inline-flex items-center gap-2 px-8 py-4 text-base font-bold bg-[#16a34a] text-white border-[3px] border-[#1a1a1a] shadow-[6px_6px_0px_0px_#1a1a1a] hover:shadow-[3px_3px_0px_0px_#1a1a1a] hover:translate-x-[3px] hover:translate-y-[3px] transition-all"
                                >
                                    Start 14-day free trial
                                    <ArrowRight className="h-5 w-5 group-hover:translate-x-1 transition-transform" />
                                </Link>
                                <div className="flex items-center gap-2 text-sm text-[#6a6a6a] font-medium">
                                    <Check className="h-4 w-4 text-[#16a34a]" />
                                    <span>No credit card required</span>
                                </div>
                            </div>

                            {/* Social proof */}
                            <div className="flex items-center gap-4 mt-10 pt-8 border-t-2 border-[#e5e5e5]">
                                <div className="flex -space-x-3">
                                    {[1, 2, 3, 4, 5].map(i => (
                                        <div key={i} className="w-10 h-10 rounded-full bg-gradient-to-br from-[#16a34a] to-[#15803d] border-[3px] border-[#f5f5f5]" />
                                    ))}
                                </div>
                                <div>
                                    <div className="flex items-center gap-1 mb-1">
                                        {[1, 2, 3, 4, 5].map(i => <Star key={i} className="h-4 w-4 fill-[#fbbf24] text-[#fbbf24]" />)}
                                    </div>
                                    <p className="text-sm font-semibold text-[#4a4a4a]">Trusted by 500+ professional traders</p>
                                </div>
                            </div>
                        </div>

                        {/* Right - Product preview card */}
                        <div className="flex-1 mt-16 lg:mt-0">
                            <div className="relative">
                                <div className="bg-white border-[3px] border-[#1a1a1a] p-6 shadow-[8px_8px_0px_0px_#1a1a1a]">
                                    <div className="flex items-center justify-between mb-6">
                                        <span className="text-sm font-bold uppercase tracking-wider text-[#6a6a6a]">Live Performance</span>
                                        <span className="px-3 py-1 text-sm font-bold bg-[#dcfce7] text-[#16a34a] border-[2px] border-[#16a34a]">+24.5%</span>
                                    </div>
                                    <div className="space-y-3">
                                        {[
                                            { name: 'MA Crossover EA', gain: '+12%', color: '#16a34a' },
                                            { name: 'RSI Scalper Pro', gain: '+8%', color: '#0ea5e9' },
                                            { name: 'Bollinger Grid', gain: '+14%', color: '#8b5cf6' }
                                        ].map((ea) => (
                                            <div key={ea.name} className="flex items-center justify-between p-4 bg-[#fafafa] border-[2px] border-[#e5e5e5] hover:border-[#1a1a1a] transition-colors">
                                                <div className="flex items-center gap-3">
                                                    <div className="w-10 h-10 flex items-center justify-center border-[2px] border-[#1a1a1a]" style={{ backgroundColor: `${ea.color}20` }}>
                                                        <TrendingUp className="h-5 w-5" style={{ color: ea.color }} />
                                                    </div>
                                                    <span className="font-semibold">{ea.name}</span>
                                                </div>
                                                <span className="font-bold text-[#16a34a]">{ea.gain}</span>
                                            </div>
                                        ))}
                                    </div>
                                </div>

                                {/* Floating badge */}
                                <div className="absolute -top-4 -right-4 px-4 py-2 bg-[#16a34a] text-white border-[3px] border-[#1a1a1a] shadow-[4px_4px_0px_0px_#1a1a1a] flex items-center gap-2">
                                    <Timer className="h-4 w-4" />
                                    <span className="font-bold text-sm">14-day free trial</span>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </section>

            {/* Stats bar */}
            <section className="px-6 py-12 lg:px-12 border-y-[3px] border-[#1a1a1a] bg-white">
                <div className="max-w-7xl mx-auto">
                    <div className="grid grid-cols-2 lg:grid-cols-4 gap-6">
                        {[
                            { label: 'Expert Advisors', value: '40+', icon: Bot },
                            { label: 'Active Traders', value: '500+', icon: Users },
                            { label: 'Validations/day', value: '10K+', icon: Activity },
                            { label: 'Uptime', value: '99.9%', icon: BarChart3 },
                        ].map(stat => (
                            <div key={stat.label} className="p-6 bg-[#f5f5f5] border-[3px] border-[#1a1a1a] shadow-[4px_4px_0px_0px_#1a1a1a]">
                                <div className="flex items-center gap-2 mb-3">
                                    <div className="w-8 h-8 bg-[#dcfce7] border-[2px] border-[#1a1a1a] flex items-center justify-center">
                                        <stat.icon className="h-4 w-4 text-[#16a34a]" />
                                    </div>
                                    <span className="text-xs font-bold uppercase tracking-wider text-[#6a6a6a]">{stat.label}</span>
                                </div>
                                <p className="text-3xl lg:text-4xl font-black">{stat.value}</p>
                            </div>
                        ))}
                    </div>
                </div>
            </section>

            {/* Why Choose Us - Comparison Section */}
            <section className="px-6 py-24 lg:px-12">
                <div className="max-w-7xl mx-auto">
                    <div className="text-center mb-16">
                        <span className="inline-block px-4 py-2 text-sm font-bold bg-[#dcfce7] text-[#16a34a] border-[3px] border-[#1a1a1a] shadow-[4px_4px_0px_0px_#1a1a1a] mb-6">
                            WHY TRADERS SWITCH
                        </span>
                        <h2 className="text-4xl lg:text-5xl font-black">Stop wasting time on manual setups</h2>
                    </div>

                    {/* Comparison Table */}
                    <div className="overflow-x-auto">
                        <div className="min-w-[600px] bg-white border-[3px] border-[#1a1a1a] shadow-[8px_8px_0px_0px_#1a1a1a]">
                            {/* Header */}
                            <div className="grid grid-cols-3 border-b-[3px] border-[#1a1a1a]">
                                <div className="p-6 font-bold text-lg">Feature</div>
                                <div className="p-6 font-bold text-lg text-center border-x-[3px] border-[#1a1a1a]">Others</div>
                                <div className="p-6 font-bold text-lg text-center bg-[#16a34a] text-white">My Algo Stack</div>
                            </div>
                            {/* Rows */}
                            {[
                                { feature: 'Pre-built Expert Advisors', others: false, us: true },
                                { feature: 'License Management', others: false, us: true },
                                { feature: 'Real-time Analytics', others: false, us: true },
                                { feature: 'Works with any broker', others: true, us: true },
                                { feature: 'Account-level control', others: false, us: true },
                                { feature: 'Instant deployment', others: false, us: true },
                                { feature: 'Free trial (no CC)', others: false, us: true },
                            ].map((row, i) => (
                                <div key={row.feature} className={`grid grid-cols-3 ${i < 6 ? 'border-b-[2px] border-[#e5e5e5]' : ''}`}>
                                    <div className="p-4 font-semibold">{row.feature}</div>
                                    <div className="p-4 flex items-center justify-center border-x-[3px] border-[#1a1a1a]">
                                        {row.others ? (
                                            <Check className="h-6 w-6 text-[#16a34a]" />
                                        ) : (
                                            <X className="h-6 w-6 text-[#ef4444]" />
                                        )}
                                    </div>
                                    <div className="p-4 flex items-center justify-center bg-[#dcfce7]">
                                        <Check className="h-6 w-6 text-[#16a34a]" />
                                    </div>
                                </div>
                            ))}
                        </div>
                    </div>
                </div>
            </section>

            {/* Features Grid */}
            <section className="px-6 py-24 lg:px-12 bg-white border-y-[3px] border-[#1a1a1a]">
                <div className="max-w-7xl mx-auto">
                    <div className="text-center mb-16">
                        <span className="inline-block px-4 py-2 text-sm font-bold bg-[#dcfce7] text-[#16a34a] border-[3px] border-[#1a1a1a] shadow-[4px_4px_0px_0px_#1a1a1a] mb-6">
                            FEATURES
                        </span>
                        <h2 className="text-4xl lg:text-5xl font-black">Everything you need to automate</h2>
                    </div>

                    {/* Bento grid */}
                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                        {/* Large card */}
                        <div className="md:col-span-2 p-8 bg-[#dcfce7] border-[3px] border-[#1a1a1a] shadow-[6px_6px_0px_0px_#1a1a1a] hover:shadow-[3px_3px_0px_0px_#1a1a1a] hover:translate-x-[3px] hover:translate-y-[3px] transition-all">
                            <div className="flex items-start gap-6">
                                <div className="w-16 h-16 bg-[#16a34a] border-[3px] border-[#1a1a1a] flex items-center justify-center shrink-0">
                                    <Bot className="h-8 w-8 text-white" />
                                </div>
                                <div>
                                    <h3 className="text-2xl font-bold mb-3">40+ Premium Expert Advisors</h3>
                                    <p className="text-[#4a4a4a] text-lg leading-relaxed">
                                        From simple moving average crossovers to complex grid systems. Scalping, swing trading,
                                        hedging — every strategy category covered with professional-grade algorithms.
                                    </p>
                                </div>
                            </div>
                        </div>

                        {/* Regular cards */}
                        <div className="p-6 bg-[#f5f5f5] border-[3px] border-[#1a1a1a] shadow-[4px_4px_0px_0px_#1a1a1a] hover:shadow-[2px_2px_0px_0px_#1a1a1a] hover:translate-x-[2px] hover:translate-y-[2px] transition-all">
                            <div className="w-14 h-14 bg-[#dbeafe] border-[3px] border-[#1a1a1a] flex items-center justify-center mb-4">
                                <Key className="h-7 w-7 text-[#0ea5e9]" />
                            </div>
                            <h3 className="text-xl font-bold mb-2">License Control</h3>
                            <p className="text-[#4a4a4a]">Bind EAs to specific accounts. Full control over who runs your bots.</p>
                        </div>

                        <div className="p-6 bg-[#f5f5f5] border-[3px] border-[#1a1a1a] shadow-[4px_4px_0px_0px_#1a1a1a] hover:shadow-[2px_2px_0px_0px_#1a1a1a] hover:translate-x-[2px] hover:translate-y-[2px] transition-all">
                            <div className="w-14 h-14 bg-[#dcfce7] border-[3px] border-[#1a1a1a] flex items-center justify-center mb-4">
                                <Activity className="h-7 w-7 text-[#16a34a]" />
                            </div>
                            <h3 className="text-xl font-bold mb-2">Live Analytics</h3>
                            <p className="text-[#4a4a4a]">Track every validation. Monitor usage patterns in real-time.</p>
                        </div>

                        <div className="p-6 bg-[#f5f5f5] border-[3px] border-[#1a1a1a] shadow-[4px_4px_0px_0px_#1a1a1a] hover:shadow-[2px_2px_0px_0px_#1a1a1a] hover:translate-x-[2px] hover:translate-y-[2px] transition-all">
                            <div className="w-14 h-14 bg-[#fce7f3] border-[3px] border-[#1a1a1a] flex items-center justify-center mb-4">
                                <Lock className="h-7 w-7 text-[#ec4899]" />
                            </div>
                            <h3 className="text-xl font-bold mb-2">Secure by Design</h3>
                            <p className="text-[#4a4a4a]">API-based validation. Your EAs only run on authorized accounts.</p>
                        </div>

                        {/* Wide card */}
                        <div className="md:col-span-2 p-6 bg-[#fef9c3] border-[3px] border-[#1a1a1a] shadow-[4px_4px_0px_0px_#1a1a1a] flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
                            <div className="flex items-center gap-4">
                                <div className="w-14 h-14 bg-[#fbbf24] border-[3px] border-[#1a1a1a] flex items-center justify-center">
                                    <Globe className="h-7 w-7 text-[#1a1a1a]" />
                                </div>
                                <div>
                                    <h3 className="text-xl font-bold">Works Everywhere</h3>
                                    <p className="text-[#4a4a4a]">Any MT4/MT5 broker worldwide. No restrictions.</p>
                                </div>
                            </div>
                            <Link href="/register" className="px-5 py-2.5 text-sm font-bold bg-white border-[3px] border-[#1a1a1a] shadow-[4px_4px_0px_0px_#1a1a1a] hover:shadow-[2px_2px_0px_0px_#1a1a1a] hover:translate-x-[2px] hover:translate-y-[2px] transition-all flex items-center gap-2">
                                Learn more <ChevronRight className="h-4 w-4" />
                            </Link>
                        </div>
                    </div>
                </div>
            </section>

            {/* Testimonials */}
            <section className="px-6 py-24 lg:px-12">
                <div className="max-w-7xl mx-auto">
                    <div className="text-center mb-16">
                        <span className="inline-block px-4 py-2 text-sm font-bold bg-[#dcfce7] text-[#16a34a] border-[3px] border-[#1a1a1a] shadow-[4px_4px_0px_0px_#1a1a1a] mb-6">
                            TESTIMONIALS
                        </span>
                        <h2 className="text-4xl lg:text-5xl font-black">Loved by traders worldwide</h2>
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                        {[
                            {
                                quote: "Saved me months of development. The license system just works — I can control exactly which accounts run my EAs.",
                                name: "Professional Trader",
                                role: "Managing 15+ prop firm accounts"
                            },
                            {
                                quote: "Finally, a platform that understands what professional traders need. The EAs are solid and the support is excellent.",
                                name: "Forex Analyst",
                                role: "6 years of trading experience"
                            },
                            {
                                quote: "The analytics dashboard alone is worth it. I can see exactly how my EAs perform across all my accounts in real-time.",
                                name: "Fund Manager",
                                role: "Managing $2M+ in client funds"
                            }
                        ].map((testimonial, i) => (
                            <div key={i} className="p-8 bg-white border-[3px] border-[#1a1a1a] shadow-[6px_6px_0px_0px_#1a1a1a]">
                                <div className="flex gap-1 mb-4">
                                    {[1, 2, 3, 4, 5].map(s => <Star key={s} className="h-5 w-5 fill-[#fbbf24] text-[#fbbf24]" />)}
                                </div>
                                <blockquote className="text-lg font-medium leading-relaxed mb-6">
                                    &ldquo;{testimonial.quote}&rdquo;
                                </blockquote>
                                <div className="flex items-center gap-3">
                                    <div className="w-12 h-12 rounded-full bg-gradient-to-br from-[#16a34a] to-[#15803d] border-[2px] border-[#1a1a1a]" />
                                    <div>
                                        <p className="font-bold">{testimonial.name}</p>
                                        <p className="text-sm text-[#6a6a6a]">{testimonial.role}</p>
                                    </div>
                                </div>
                            </div>
                        ))}
                    </div>
                </div>
            </section>

            {/* Pricing Teaser */}
            <section className="px-6 py-24 lg:px-12 bg-white border-y-[3px] border-[#1a1a1a]">
                <div className="max-w-4xl mx-auto">
                    <div className="text-center mb-16">
                        <span className="inline-block px-4 py-2 text-sm font-bold bg-[#dcfce7] text-[#16a34a] border-[3px] border-[#1a1a1a] shadow-[4px_4px_0px_0px_#1a1a1a] mb-6">
                            SIMPLE PRICING
                        </span>
                        <h2 className="text-4xl lg:text-5xl font-black">Start free, upgrade anytime</h2>
                        <p className="mt-4 text-lg text-[#6a6a6a]">No hidden fees. Cancel anytime.</p>
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                        {/* Free Plan */}
                        <div className="p-8 bg-[#f5f5f5] border-[3px] border-[#1a1a1a] shadow-[4px_4px_0px_0px_#1a1a1a]">
                            <h3 className="text-2xl font-bold mb-2">Free Trial</h3>
                            <p className="text-[#6a6a6a] mb-6">Perfect to get started</p>
                            <div className="mb-6">
                                <span className="text-4xl font-black">$0</span>
                                <span className="text-[#6a6a6a]">/14 days</span>
                            </div>
                            <ul className="space-y-3 mb-8">
                                {['Access to all EAs', 'Up to 2 accounts', 'Basic analytics', 'Email support'].map(feature => (
                                    <li key={feature} className="flex items-center gap-2 font-medium">
                                        <Check className="h-5 w-5 text-[#16a34a]" /> {feature}
                                    </li>
                                ))}
                            </ul>
                            <Link href="/register" className="block w-full py-3 text-center font-bold border-[3px] border-[#1a1a1a] shadow-[4px_4px_0px_0px_#1a1a1a] hover:shadow-[2px_2px_0px_0px_#1a1a1a] hover:translate-x-[2px] hover:translate-y-[2px] transition-all">
                                Start free trial
                            </Link>
                        </div>

                        {/* Pro Plan */}
                        <div className="relative p-8 bg-[#16a34a] text-white border-[3px] border-[#1a1a1a] shadow-[6px_6px_0px_0px_#1a1a1a]">
                            <div className="absolute -top-4 left-1/2 -translate-x-1/2 px-4 py-1 bg-[#fbbf24] text-[#1a1a1a] font-bold text-sm border-[2px] border-[#1a1a1a]">
                                MOST POPULAR
                            </div>
                            <h3 className="text-2xl font-bold mb-2">Pro</h3>
                            <p className="text-white/80 mb-6">For serious traders</p>
                            <div className="mb-6">
                                <span className="text-4xl font-black">$49</span>
                                <span className="text-white/80">/month</span>
                            </div>
                            <ul className="space-y-3 mb-8">
                                {['Unlimited EAs', 'Unlimited accounts', 'Advanced analytics', 'Priority support', 'API access'].map(feature => (
                                    <li key={feature} className="flex items-center gap-2 font-medium">
                                        <Check className="h-5 w-5 text-[#fbbf24]" /> {feature}
                                    </li>
                                ))}
                            </ul>
                            <Link href="/register" className="block w-full py-3 text-center font-bold bg-white text-[#16a34a] border-[3px] border-[#1a1a1a] shadow-[4px_4px_0px_0px_#1a1a1a] hover:shadow-[2px_2px_0px_0px_#1a1a1a] hover:translate-x-[2px] hover:translate-y-[2px] transition-all">
                                Get started now
                            </Link>
                        </div>
                    </div>
                </div>
            </section>

            {/* Final CTA */}
            <section className="px-6 py-32 lg:px-12">
                <div className="max-w-3xl mx-auto text-center">
                    <h2 className="text-4xl lg:text-6xl font-black mb-6">
                        Ready to automate your trading?
                    </h2>
                    <p className="text-xl text-[#4a4a4a] mb-10 max-w-xl mx-auto">
                        Join 500+ traders who are already using My Algo Stack to grow their accounts on autopilot.
                    </p>
                    <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
                        <Link
                            href="/register"
                            className="inline-flex items-center gap-2 px-10 py-5 text-lg font-bold bg-[#16a34a] text-white border-[3px] border-[#1a1a1a] shadow-[6px_6px_0px_0px_#1a1a1a] hover:shadow-[3px_3px_0px_0px_#1a1a1a] hover:translate-x-[3px] hover:translate-y-[3px] transition-all"
                        >
                            Start your free trial
                            <ArrowRight className="h-5 w-5" />
                        </Link>
                    </div>
                    <p className="mt-6 text-sm text-[#6a6a6a] font-medium">
                        <Check className="h-4 w-4 inline mr-1 text-[#16a34a]" />
                        No credit card required
                        <span className="mx-3">•</span>
                        <Timer className="h-4 w-4 inline mr-1 text-[#16a34a]" />
                        14-day free trial
                        <span className="mx-3">•</span>
                        <Lock className="h-4 w-4 inline mr-1 text-[#16a34a]" />
                        Cancel anytime
                    </p>
                </div>
            </section>

            {/* Footer */}
            <footer className="px-6 py-12 lg:px-12 border-t-[3px] border-[#1a1a1a]">
                <div className="max-w-7xl mx-auto">
                    <div className="flex flex-col md:flex-row items-center justify-between gap-6">
                        <div className="flex items-center gap-3">
                            <div className="w-8 h-8 bg-[#16a34a] border-[2px] border-[#1a1a1a] flex items-center justify-center">
                                <Layers className="h-4 w-4 text-white" />
                            </div>
                            <span className="font-bold">My Algo Stack</span>
                        </div>
                        <p className="text-sm text-[#6a6a6a] font-medium">© {new Date().getFullYear()} My Algo Stack. All rights reserved.</p>
                        <div className="flex items-center gap-6 text-sm font-semibold text-[#4a4a4a]">
                            <Link href="/privacy" className="hover:text-[#16a34a] transition-colors">Privacy</Link>
                            <Link href="/terms" className="hover:text-[#16a34a] transition-colors">Terms</Link>
                            <Link href="/contact" className="hover:text-[#16a34a] transition-colors">Contact</Link>
                            <Link href="/login" className="hover:text-[#16a34a] transition-colors">Login</Link>
                        </div>
                    </div>
                </div>
            </footer>
        </div>
    )
}
