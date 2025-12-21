import { Metadata } from "next"

export const metadata: Metadata = {
    title: "Terms of Service | My Algo Stack",
    description: "Terms of Service for My Algo Stack EA License System",
}

export default function TermsPage() {
    return (
        <div className="min-h-screen bg-gradient-to-b from-slate-900 to-slate-800 py-12">
            <div className="container mx-auto max-w-4xl px-4">
                <div className="bg-slate-800/50 backdrop-blur border border-slate-700 rounded-lg p-8">
                    <h1 className="text-3xl font-bold text-white mb-8">Terms of Service</h1>

                    <div className="prose prose-invert prose-slate max-w-none">
                        <p className="text-slate-300 mb-6">
                            <strong>Last updated:</strong> December 21, 2024
                        </p>

                        <section className="mb-8">
                            <h2 className="text-xl font-semibold text-white mb-4">1. Acceptance of Terms</h2>
                            <p className="text-slate-300">
                                By accessing or using My Algo Stack (&quot;the Service&quot;), you agree to be bound by these
                                Terms of Service. If you do not agree to these terms, please do not use the Service.
                            </p>
                        </section>

                        <section className="mb-8">
                            <h2 className="text-xl font-semibold text-white mb-4">2. Description of Service</h2>
                            <p className="text-slate-300">
                                My Algo Stack provides a license management system for MetaTrader Expert Advisors (EAs).
                                The Service includes license validation, trade tracking, performance analytics, and
                                notification features.
                            </p>
                        </section>

                        <section className="mb-8">
                            <h2 className="text-xl font-semibold text-white mb-4">3. Account Registration</h2>
                            <p className="text-slate-300 mb-4">
                                To use the Service, you must:
                            </p>
                            <ul className="list-disc pl-6 text-slate-300 space-y-2">
                                <li>Provide accurate and complete registration information</li>
                                <li>Maintain the security of your account credentials</li>
                                <li>Be at least 18 years of age</li>
                                <li>Not share your account with others</li>
                            </ul>
                        </section>

                        <section className="mb-8">
                            <h2 className="text-xl font-semibold text-white mb-4">4. Trading Risk Disclaimer</h2>
                            <p className="text-slate-300 font-semibold text-yellow-400 mb-4">
                                ⚠️ IMPORTANT: Trading in financial markets involves substantial risk of loss.
                            </p>
                            <ul className="list-disc pl-6 text-slate-300 space-y-2">
                                <li>Past performance does not guarantee future results</li>
                                <li>Expert Advisors may experience losses and technical failures</li>
                                <li>You are solely responsible for your trading decisions</li>
                                <li>We do not provide financial or investment advice</li>
                                <li>Only trade with capital you can afford to lose</li>
                            </ul>
                        </section>

                        <section className="mb-8">
                            <h2 className="text-xl font-semibold text-white mb-4">5. License Terms</h2>
                            <p className="text-slate-300 mb-4">
                                Subject to these Terms, we grant you a limited, non-exclusive, non-transferable license to:
                            </p>
                            <ul className="list-disc pl-6 text-slate-300 space-y-2">
                                <li>Use Expert Advisors on the number of accounts allowed by your subscription tier</li>
                                <li>Access the dashboard and analytics features</li>
                                <li>Receive notifications for your trading activity</li>
                            </ul>
                            <p className="text-slate-300 mt-4">
                                You may not redistribute, resell, or share your license credentials with others.
                            </p>
                        </section>

                        <section className="mb-8">
                            <h2 className="text-xl font-semibold text-white mb-4">6. Subscription and Payments</h2>
                            <p className="text-slate-300 mb-4">
                                Subscription tiers determine the number of MT accounts you can register:
                            </p>
                            <ul className="list-disc pl-6 text-slate-300 space-y-2">
                                <li><strong>Beginner</strong> - 1 account</li>
                                <li><strong>Trader</strong> - 5 accounts</li>
                                <li><strong>Investor</strong> - 10 accounts</li>
                            </ul>
                        </section>

                        <section className="mb-8">
                            <h2 className="text-xl font-semibold text-white mb-4">7. Limitation of Liability</h2>
                            <p className="text-slate-300">
                                TO THE MAXIMUM EXTENT PERMITTED BY LAW, WE SHALL NOT BE LIABLE FOR ANY INDIRECT,
                                INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, INCLUDING BUT NOT LIMITED TO
                                LOSS OF PROFITS, TRADING LOSSES, DATA LOSS, OR OTHER INTANGIBLE LOSSES, RESULTING FROM
                                YOUR USE OF THE SERVICE.
                            </p>
                        </section>

                        <section className="mb-8">
                            <h2 className="text-xl font-semibold text-white mb-4">8. Service Availability</h2>
                            <p className="text-slate-300">
                                We strive to maintain high availability but do not guarantee uninterrupted service.
                                We may perform maintenance, updates, or experience outages. License validation may
                                be temporarily unavailable, and you should implement appropriate fallback logic in
                                your Expert Advisors.
                            </p>
                        </section>

                        <section className="mb-8">
                            <h2 className="text-xl font-semibold text-white mb-4">9. Account Termination</h2>
                            <p className="text-slate-300">
                                We reserve the right to suspend or terminate your account if you violate these Terms,
                                engage in fraudulent activity, or abuse the Service. You may also request account
                                deletion at any time.
                            </p>
                        </section>

                        <section className="mb-8">
                            <h2 className="text-xl font-semibold text-white mb-4">10. Changes to Terms</h2>
                            <p className="text-slate-300">
                                We may update these Terms from time to time. We will notify you of significant changes
                                via email or through the Service. Continued use after changes constitutes acceptance
                                of the updated Terms.
                            </p>
                        </section>

                        <section className="mb-8">
                            <h2 className="text-xl font-semibold text-white mb-4">11. Contact Us</h2>
                            <p className="text-slate-300">
                                If you have questions about these Terms, please contact us at{" "}
                                <a href="mailto:support@myalgostack.com" className="text-primary hover:underline">
                                    support@myalgostack.com
                                </a>
                            </p>
                        </section>
                    </div>
                </div>
            </div>
        </div>
    )
}
