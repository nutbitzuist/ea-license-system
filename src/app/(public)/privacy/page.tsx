import { Metadata } from "next"

export const metadata: Metadata = {
    title: "Privacy Policy | My Algo Stack",
    description: "Privacy Policy for My Algo Stack EA License System",
}

export default function PrivacyPage() {
    return (
        <div className="min-h-screen bg-gradient-to-b from-slate-900 to-slate-800 py-12">
            <div className="container mx-auto max-w-4xl px-4">
                <div className="bg-slate-800/50 backdrop-blur border border-slate-700 rounded-lg p-8">
                    <h1 className="text-3xl font-bold text-white mb-8">Privacy Policy</h1>

                    <div className="prose prose-invert prose-slate max-w-none">
                        <p className="text-slate-300 mb-6">
                            <strong>Last updated:</strong> December 21, 2024
                        </p>

                        <section className="mb-8">
                            <h2 className="text-xl font-semibold text-white mb-4">1. Information We Collect</h2>
                            <p className="text-slate-300 mb-4">
                                We collect information you provide directly to us, including:
                            </p>
                            <ul className="list-disc pl-6 text-slate-300 space-y-2">
                                <li>Account information (name, email address)</li>
                                <li>MetaTrader account numbers and broker names</li>
                                <li>Trading data submitted by Expert Advisors (trade history, positions)</li>
                                <li>License validation logs (IP addresses, timestamps)</li>
                            </ul>
                        </section>

                        <section className="mb-8">
                            <h2 className="text-xl font-semibold text-white mb-4">2. How We Use Your Information</h2>
                            <p className="text-slate-300 mb-4">
                                We use the information we collect to:
                            </p>
                            <ul className="list-disc pl-6 text-slate-300 space-y-2">
                                <li>Provide, maintain, and improve our services</li>
                                <li>Validate Expert Advisor licenses</li>
                                <li>Track trading performance and analytics</li>
                                <li>Send you notifications about your account and trades</li>
                                <li>Respond to your requests and support inquiries</li>
                            </ul>
                        </section>

                        <section className="mb-8">
                            <h2 className="text-xl font-semibold text-white mb-4">3. Data Security</h2>
                            <p className="text-slate-300">
                                We implement appropriate technical and organizational measures to protect your personal
                                information against unauthorized access, alteration, disclosure, or destruction.
                                This includes encryption of data in transit and at rest, secure authentication,
                                and regular security audits.
                            </p>
                        </section>

                        <section className="mb-8">
                            <h2 className="text-xl font-semibold text-white mb-4">4. Data Retention</h2>
                            <p className="text-slate-300">
                                We retain your personal information for as long as your account is active or as
                                needed to provide you services. You may request deletion of your account and
                                associated data at any time by contacting us.
                            </p>
                        </section>

                        <section className="mb-8">
                            <h2 className="text-xl font-semibold text-white mb-4">5. Third-Party Services</h2>
                            <p className="text-slate-300 mb-4">
                                We use the following third-party services:
                            </p>
                            <ul className="list-disc pl-6 text-slate-300 space-y-2">
                                <li><strong>Supabase</strong> - Database hosting</li>
                                <li><strong>Vercel</strong> - Application hosting</li>
                                <li><strong>Resend</strong> - Email delivery</li>
                                <li><strong>Discord/Telegram</strong> - Optional trade notifications (if configured)</li>
                            </ul>
                        </section>

                        <section className="mb-8">
                            <h2 className="text-xl font-semibold text-white mb-4">6. Your Rights</h2>
                            <p className="text-slate-300 mb-4">
                                You have the right to:
                            </p>
                            <ul className="list-disc pl-6 text-slate-300 space-y-2">
                                <li>Access your personal data</li>
                                <li>Correct inaccurate data</li>
                                <li>Request deletion of your data</li>
                                <li>Export your data</li>
                                <li>Withdraw consent for data processing</li>
                            </ul>
                        </section>

                        <section className="mb-8">
                            <h2 className="text-xl font-semibold text-white mb-4">7. Cookies</h2>
                            <p className="text-slate-300">
                                We use essential cookies only for authentication and session management.
                                We do not use tracking or advertising cookies.
                            </p>
                        </section>

                        <section className="mb-8">
                            <h2 className="text-xl font-semibold text-white mb-4">8. Contact Us</h2>
                            <p className="text-slate-300">
                                If you have questions about this Privacy Policy, please contact us at{" "}
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
