import Link from "next/link"
import { Shield, Bot, Key, Activity, ArrowRight, Zap, Globe, Lock, Star, TrendingUp, BarChart3, Users } from "lucide-react"

export default function LandingPage() {
    return (
        <div className="bg-[#0a0a0a] text-white overflow-hidden">
            {/* Floating decorative elements */}
            <div className="fixed inset-0 pointer-events-none overflow-hidden">
                <div className="absolute top-20 left-10 w-72 h-72 bg-purple-500/10 rounded-full blur-[100px]" />
                <div className="absolute bottom-40 right-10 w-96 h-96 bg-blue-500/10 rounded-full blur-[120px]" />
            </div>

            {/* Navigation */}
            <nav className="relative z-50 flex items-center justify-between px-8 py-6 lg:px-16">
                <Link href="/" className="flex items-center gap-3 group">
                    <div className="relative">
                        <div className="absolute inset-0 bg-purple-500 rounded-xl blur-lg opacity-50 group-hover:opacity-100 transition-opacity" />
                        <div className="relative w-10 h-10 bg-gradient-to-br from-purple-500 to-purple-700 rounded-xl flex items-center justify-center">
                            <Shield className="h-5 w-5" />
                        </div>
                    </div>
                    <span className="text-xl font-semibold tracking-tight">My Algo Stack</span>
                </Link>

                <div className="flex items-center gap-2">
                    <Link href="/login" className="px-5 py-2.5 text-sm text-gray-400 hover:text-white transition-colors">
                        Login
                    </Link>
                    <Link href="/register" className="px-5 py-2.5 text-sm font-medium bg-white text-black rounded-full hover:bg-gray-100 transition-colors">
                        Get Started
                    </Link>
                </div>
            </nav>

            {/* Hero */}
            <section className="relative z-10 px-8 pt-20 pb-32 lg:px-16 lg:pt-32">
                <div className="max-w-6xl mx-auto">
                    <div className="flex flex-col lg:flex-row lg:items-center lg:gap-16">
                        {/* Left content */}
                        <div className="flex-1">
                            <div className="inline-flex items-center gap-2 px-3 py-1 mb-8 text-xs font-medium bg-white/5 border border-white/10 rounded-full">
                                <span className="w-2 h-2 bg-green-500 rounded-full animate-pulse" />
                                <span className="text-gray-400">500+ traders automated</span>
                            </div>

                            <h1 className="text-5xl lg:text-7xl font-bold leading-[1.05] tracking-tight">
                                Trade smarter,
                                <br />
                                <span className="text-transparent bg-clip-text bg-gradient-to-r from-purple-400 via-pink-400 to-purple-400">
                                    not harder
                                </span>
                            </h1>

                            <p className="mt-8 text-lg text-gray-400 max-w-md leading-relaxed">
                                40+ battle-tested Expert Advisors with built-in license management.
                                Deploy in minutes.
                            </p>

                            <div className="flex items-center gap-4 mt-10">
                                <Link
                                    href="/register"
                                    className="group inline-flex items-center gap-2 px-6 py-3.5 text-sm font-medium bg-white text-black rounded-full hover:bg-gray-100 transition-all"
                                >
                                    Start free trial
                                    <ArrowRight className="h-4 w-4 group-hover:translate-x-0.5 transition-transform" />
                                </Link>
                                <div className="flex items-center gap-2 text-sm text-gray-500">
                                    <div className="flex -space-x-2">
                                        {[1, 2, 3, 4].map(i => (
                                            <div key={i} className="w-8 h-8 rounded-full bg-gradient-to-br from-gray-700 to-gray-800 border-2 border-[#0a0a0a]" />
                                        ))}
                                    </div>
                                    <span>Join 500+ traders</span>
                                </div>
                            </div>
                        </div>

                        {/* Right - Floating cards */}
                        <div className="flex-1 mt-16 lg:mt-0 relative">
                            <div className="relative w-full aspect-square max-w-md mx-auto">
                                {/* Main card */}
                                <div className="absolute inset-4 bg-gradient-to-br from-gray-900 to-gray-950 rounded-3xl border border-white/10 p-6 shadow-2xl">
                                    <div className="flex items-center justify-between mb-6">
                                        <span className="text-xs font-medium text-gray-500 uppercase tracking-wider">Live Performance</span>
                                        <span className="px-2 py-1 text-xs bg-green-500/10 text-green-400 rounded-full">+24.5%</span>
                                    </div>
                                    <div className="space-y-4">
                                        {['MA Crossover EA', 'RSI Scalper EA', 'Bollinger EA'].map((name, i) => (
                                            <div key={name} className="flex items-center justify-between p-3 bg-white/5 rounded-xl">
                                                <div className="flex items-center gap-3">
                                                    <div className={`w-8 h-8 rounded-lg flex items-center justify-center ${i === 0 ? 'bg-purple-500/20' : i === 1 ? 'bg-blue-500/20' : 'bg-pink-500/20'}`}>
                                                        <TrendingUp className={`h-4 w-4 ${i === 0 ? 'text-purple-400' : i === 1 ? 'text-blue-400' : 'text-pink-400'}`} />
                                                    </div>
                                                    <span className="text-sm font-medium">{name}</span>
                                                </div>
                                                <span className="text-sm text-green-400">+{8 + i * 3}%</span>
                                            </div>
                                        ))}
                                    </div>
                                </div>

                                {/* Floating badge */}
                                <div className="absolute -top-2 -right-2 px-4 py-2 bg-gradient-to-r from-purple-600 to-pink-600 rounded-full text-sm font-medium shadow-lg shadow-purple-500/25">
                                    <span className="flex items-center gap-1.5">
                                        <Zap className="h-3.5 w-3.5" />
                                        14-day free
                                    </span>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </section>

            {/* Stats bar */}
            <section className="relative z-10 px-8 py-12 lg:px-16 border-y border-white/5">
                <div className="max-w-6xl mx-auto">
                    <div className="grid grid-cols-2 lg:grid-cols-4 gap-8">
                        {[
                            { label: 'Expert Advisors', value: '40+', icon: Bot },
                            { label: 'Active Traders', value: '500+', icon: Users },
                            { label: 'Validations/day', value: '10K+', icon: Activity },
                            { label: 'Uptime', value: '99.9%', icon: BarChart3 },
                        ].map(stat => (
                            <div key={stat.label} className="text-center lg:text-left">
                                <div className="inline-flex items-center gap-2 text-gray-500 mb-2">
                                    <stat.icon className="h-4 w-4" />
                                    <span className="text-xs uppercase tracking-wider">{stat.label}</span>
                                </div>
                                <p className="text-3xl lg:text-4xl font-bold">{stat.value}</p>
                            </div>
                        ))}
                    </div>
                </div>
            </section>

            {/* Bento Grid Features */}
            <section className="relative z-10 px-8 py-24 lg:px-16">
                <div className="max-w-6xl mx-auto">
                    <div className="text-center mb-16">
                        <span className="inline-block px-3 py-1 text-xs font-medium text-purple-400 bg-purple-500/10 rounded-full mb-4">
                            Why traders choose us
                        </span>
                        <h2 className="text-4xl lg:text-5xl font-bold">Everything you need</h2>
                    </div>

                    {/* Bento grid */}
                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                        {/* Large card */}
                        <div className="md:col-span-2 p-8 bg-gradient-to-br from-purple-500/10 to-transparent border border-white/10 rounded-3xl">
                            <div className="flex items-start gap-6">
                                <div className="w-14 h-14 bg-purple-500/20 rounded-2xl flex items-center justify-center shrink-0">
                                    <Bot className="h-7 w-7 text-purple-400" />
                                </div>
                                <div>
                                    <h3 className="text-xl font-semibold mb-2">40+ Premium Expert Advisors</h3>
                                    <p className="text-gray-400 leading-relaxed">
                                        From simple moving average crossovers to complex grid systems. Scalping, swing trading,
                                        hedging — every strategy category covered with professional-grade algorithms.
                                    </p>
                                </div>
                            </div>
                        </div>

                        {/* Regular cards */}
                        <div className="p-6 bg-white/5 border border-white/10 rounded-3xl hover:bg-white/[0.07] transition-colors">
                            <div className="w-12 h-12 bg-blue-500/20 rounded-xl flex items-center justify-center mb-4">
                                <Key className="h-6 w-6 text-blue-400" />
                            </div>
                            <h3 className="text-lg font-semibold mb-2">License Control</h3>
                            <p className="text-sm text-gray-400">Bind EAs to specific accounts. Full control over who runs your bots.</p>
                        </div>

                        <div className="p-6 bg-white/5 border border-white/10 rounded-3xl hover:bg-white/[0.07] transition-colors">
                            <div className="w-12 h-12 bg-green-500/20 rounded-xl flex items-center justify-center mb-4">
                                <Activity className="h-6 w-6 text-green-400" />
                            </div>
                            <h3 className="text-lg font-semibold mb-2">Live Analytics</h3>
                            <p className="text-sm text-gray-400">Track every validation. Monitor usage patterns in real-time.</p>
                        </div>

                        <div className="p-6 bg-white/5 border border-white/10 rounded-3xl hover:bg-white/[0.07] transition-colors">
                            <div className="w-12 h-12 bg-pink-500/20 rounded-xl flex items-center justify-center mb-4">
                                <Lock className="h-6 w-6 text-pink-400" />
                            </div>
                            <h3 className="text-lg font-semibold mb-2">Secure by Design</h3>
                            <p className="text-sm text-gray-400">API-based validation. Your EAs only run on authorized accounts.</p>
                        </div>

                        {/* Wide card */}
                        <div className="md:col-span-2 p-6 bg-gradient-to-r from-white/5 to-transparent border border-white/10 rounded-3xl flex items-center justify-between">
                            <div className="flex items-center gap-4">
                                <div className="w-12 h-12 bg-orange-500/20 rounded-xl flex items-center justify-center">
                                    <Globe className="h-6 w-6 text-orange-400" />
                                </div>
                                <div>
                                    <h3 className="text-lg font-semibold">Works Everywhere</h3>
                                    <p className="text-sm text-gray-400">Any MT4/MT5 broker worldwide. No restrictions.</p>
                                </div>
                            </div>
                            <Link href="/register" className="px-4 py-2 text-sm bg-white/10 rounded-full hover:bg-white/20 transition-colors">
                                Learn more →
                            </Link>
                        </div>
                    </div>
                </div>
            </section>

            {/* Testimonial */}
            <section className="relative z-10 px-8 py-24 lg:px-16">
                <div className="max-w-4xl mx-auto">
                    <div className="relative p-12 bg-gradient-to-br from-white/5 to-transparent border border-white/10 rounded-[2.5rem]">
                        <div className="absolute -top-4 left-12 flex gap-1">
                            {[1, 2, 3, 4, 5].map(i => <Star key={i} className="h-5 w-5 fill-yellow-500 text-yellow-500" />)}
                        </div>
                        <blockquote className="text-2xl lg:text-3xl font-medium leading-relaxed mb-8">
                            &ldquo;Saved me months of development. The license system just works —
                            I can control exactly which accounts run my EAs.&rdquo;
                        </blockquote>
                        <div className="flex items-center gap-4">
                            <div className="w-12 h-12 rounded-full bg-gradient-to-br from-purple-400 to-pink-400" />
                            <div>
                                <p className="font-medium">Professional Trader</p>
                                <p className="text-sm text-gray-500">Managing 15+ prop firm accounts</p>
                            </div>
                        </div>
                    </div>
                </div>
            </section>

            {/* CTA */}
            <section className="relative z-10 px-8 py-32 lg:px-16">
                <div className="max-w-3xl mx-auto text-center">
                    <h2 className="text-4xl lg:text-6xl font-bold mb-6">
                        Ready to automate?
                    </h2>
                    <p className="text-xl text-gray-400 mb-10">
                        Start your 14-day free trial. No credit card required.
                    </p>
                    <Link
                        href="/register"
                        className="inline-flex items-center gap-2 px-8 py-4 text-base font-medium bg-white text-black rounded-full hover:bg-gray-100 transition-all"
                    >
                        Get started for free
                        <ArrowRight className="h-4 w-4" />
                    </Link>
                </div>
            </section>

            {/* Footer */}
            <footer className="relative z-10 px-8 py-8 lg:px-16 border-t border-white/5">
                <div className="max-w-6xl mx-auto flex flex-col md:flex-row items-center justify-between gap-4">
                    <div className="flex items-center gap-2">
                        <Shield className="h-5 w-5 text-purple-500" />
                        <span className="font-medium">My Algo Stack</span>
                    </div>
                    <p className="text-sm text-gray-600">© {new Date().getFullYear()} All rights reserved.</p>
                    <div className="flex items-center gap-6 text-sm text-gray-500">
                        <Link href="/privacy" className="hover:text-white transition-colors">Privacy</Link>
                        <Link href="/terms" className="hover:text-white transition-colors">Terms</Link>
                        <Link href="/login" className="hover:text-white transition-colors">Login</Link>
                        <Link href="/register" className="hover:text-white transition-colors">Register</Link>
                    </div>
                </div>
            </footer>
        </div>
    )
}
