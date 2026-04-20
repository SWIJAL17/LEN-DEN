import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { Link } from 'react-router-dom';
import LendenLogo from '../components/LendenLogo';

const fadeUp = { hidden: { opacity: 0, y: 40 }, visible: { opacity: 1, y: 0 } };

const Home = () => {
  const [mobileMenu, setMobileMenu] = useState(false);

  return (
    <div className="min-h-screen bg-dark-900 text-white overflow-hidden noise-bg">
      {/* ══════════ Ambient Gradients ══════════ */}
      <div className="fixed inset-0 z-0 pointer-events-none">
        <div className="absolute top-[-20%] left-[-10%] w-[50%] h-[50%] bg-violet-600/15 rounded-full blur-[160px] animate-glow-pulse" />
        <div className="absolute bottom-[-15%] right-[-10%] w-[45%] h-[45%] bg-indigo-500/12 rounded-full blur-[140px] animate-glow-pulse" style={{ animationDelay: '2s' }} />
        <div className="absolute top-[50%] left-[50%] w-[30%] h-[30%] bg-fuchsia-500/8 rounded-full blur-[120px] animate-glow-pulse" style={{ animationDelay: '4s' }} />
      </div>

      {/* ══════════ HEADER ══════════ */}
      <header className="relative z-20 border-b border-white/[0.04]">
        <nav className="flex items-center justify-between px-6 lg:px-12 py-5 max-w-7xl mx-auto">
          {/* Logo */}
          <Link to="/" className="flex items-center gap-3 group">
            <LendenLogo size={40} className="transition-transform group-hover:scale-105" />
            <span className="font-display font-bold text-2xl tracking-tight">
              Len<span className="text-violet-400">den</span>
            </span>
          </Link>

          {/* Desktop Nav */}
          <div className="hidden md:flex items-center gap-8 text-sm font-medium text-white/60">
            <a href="#features" className="hover:text-white transition-colors duration-200">Features</a>
            <a href="#how-it-works" className="hover:text-white transition-colors duration-200">How it works</a>
            <a href="#stats" className="hover:text-white transition-colors duration-200">Statistics</a>
            <a href="#testimonials" className="hover:text-white transition-colors duration-200">Reviews</a>
          </div>

          {/* CTA */}
          <div className="hidden md:flex items-center gap-4">
            <Link to="/login" className="text-sm font-medium text-white/60 hover:text-white transition-colors px-4 py-2">Sign In</Link>
            <Link to="/signup" className="btn-gradient !py-2.5 !px-6 text-sm"><span>Get Started Free</span></Link>
          </div>

          {/* Mobile Toggle */}
          <button onClick={() => setMobileMenu(!mobileMenu)} className="md:hidden text-white/70 p-2">
            <svg width="24" height="24" fill="none" stroke="currentColor" strokeWidth="2">
              {mobileMenu ? <path d="M6 6l12 12M6 18L18 6" /> : <path d="M4 6h16M4 12h16M4 18h16" />}
            </svg>
          </button>
        </nav>

        {/* Mobile Menu */}
        {mobileMenu && (
          <motion.div initial={{ opacity: 0, height: 0 }} animate={{ opacity: 1, height: 'auto' }} className="md:hidden border-t border-white/5 bg-dark-800/90 backdrop-blur-xl px-6 py-6 space-y-4">
            <a href="#features" className="block text-sm text-white/60 hover:text-white">Features</a>
            <a href="#how-it-works" className="block text-sm text-white/60 hover:text-white">How it works</a>
            <a href="#stats" className="block text-sm text-white/60 hover:text-white">Statistics</a>
            <div className="flex gap-3 pt-4 border-t border-white/5">
              <Link to="/login" className="btn-outline flex-1 text-center text-sm !py-2.5">Sign In</Link>
              <Link to="/signup" className="btn-gradient flex-1 text-center text-sm !py-2.5"><span>Get Started</span></Link>
            </div>
          </motion.div>
        )}
      </header>

      {/* ══════════ HERO ══════════ */}
      <main className="relative z-10">
        <section className="max-w-7xl mx-auto px-6 lg:px-12 pt-24 pb-32">
          <div className="flex flex-col lg:flex-row items-center gap-20">
            <motion.div className="flex-1 text-center lg:text-left" initial="hidden" animate="visible" variants={fadeUp} transition={{ duration: 0.7 }}>
              <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-violet-500/10 border border-violet-500/20 text-violet-400 text-sm font-medium mb-8">
                <span className="w-2 h-2 rounded-full bg-violet-400 animate-pulse" />
                Trusted by 12,000+ investors across India
              </div>
              <h1 className="font-display text-5xl lg:text-7xl font-extrabold leading-[1.1] mb-7 tracking-tight">
                The future of{' '}
                <span className="text-transparent bg-clip-text bg-gradient-to-r from-violet-400 via-indigo-400 to-blue-400 animate-gradient">
                  peer-to-peer
                </span>
                <br />lending is here.
              </h1>
              <p className="text-lg lg:text-xl text-white/45 mb-10 max-w-xl mx-auto lg:mx-0 leading-relaxed">
                Connect directly with verified borrowers to earn premium returns, or get funded instantly without traditional banking hurdles.
              </p>
              <div className="flex flex-col sm:flex-row items-center gap-4 justify-center lg:justify-start">
                <Link to="/signup" className="btn-gradient w-full sm:w-auto !py-4 !px-8 text-lg font-semibold shadow-glow-purple">
                  <span className="flex items-center justify-center gap-2">Start Investing <span>→</span></span>
                </Link>
                <Link to="/signup" className="w-full sm:w-auto px-8 py-4 rounded-xl text-lg font-semibold text-white border border-white/10 hover:border-violet-500/30 hover:bg-violet-500/5 transition-all text-center">
                  Apply for Loan
                </Link>
              </div>
              {/* Trust Indicators */}
              <div className="flex flex-wrap items-center gap-6 mt-12 justify-center lg:justify-start text-sm text-white/30">
                <div className="flex items-center gap-2"><span className="text-emerald-400 text-base">✓</span> RBI Compliant</div>
                <div className="flex items-center gap-2"><span className="text-emerald-400 text-base">✓</span> 256-bit Encryption</div>
                <div className="flex items-center gap-2"><span className="text-emerald-400 text-base">✓</span> KYC Verified</div>
              </div>
            </motion.div>

            {/* Hero Dashboard Preview */}
            <motion.div initial={{ opacity: 0, scale: 0.92 }} animate={{ opacity: 1, scale: 1 }} transition={{ duration: 0.8, delay: 0.3 }} className="flex-1 relative w-full max-w-lg">
              <div className="relative z-10 glass-card p-6 border border-white/[0.08] shadow-2xl">
                <div className="flex justify-between items-center mb-6">
                  <div>
                    <p className="text-xs text-white/40 mb-1 uppercase tracking-wide">Portfolio Value</p>
                    <p className="text-3xl font-bold font-display text-white">₹12,45,000</p>
                  </div>
                  <div className="px-3 py-1 rounded-full bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 text-sm font-semibold">
                    +18.4% ↑
                  </div>
                </div>
                <div className="space-y-3">
                  {[
                    { title: 'Small Business Loan', amount: '₹2,50,000', rate: '12%', progress: 85, color: 'from-violet-500 to-indigo-500' },
                    { title: 'Education Fund - MBA', amount: '₹5,00,000', rate: '10%', progress: 100, color: 'from-emerald-500 to-teal-500' },
                    { title: 'Farm Equipment Lease', amount: '₹1,50,000', rate: '14%', progress: 42, color: 'from-amber-500 to-orange-500' },
                  ].map((loan, i) => (
                    <div key={i} className="p-4 rounded-xl bg-white/[0.03] border border-white/[0.04] hover:bg-white/[0.05] transition-colors">
                      <div className="flex justify-between mb-2">
                        <span className="font-medium text-sm text-white">{loan.title}</span>
                        <span className="text-sm font-semibold text-violet-400">{loan.rate} APR</span>
                      </div>
                      <div className="flex justify-between text-xs text-white/35 mb-2">
                        <span>{loan.amount}</span>
                        <span>{loan.progress}% Funded</span>
                      </div>
                      <div className="h-1.5 w-full bg-white/[0.06] rounded-full overflow-hidden">
                        <motion.div initial={{ width: 0 }} animate={{ width: `${loan.progress}%` }} transition={{ duration: 1.5, delay: 0.5 + i * 0.2 }}
                          className={`h-full bg-gradient-to-r ${loan.color} rounded-full`} />
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              {/* Floating Cards */}
              <motion.div animate={{ y: [0, -8, 0] }} transition={{ repeat: Infinity, duration: 4 }}
                className="absolute -top-8 -right-8 glass-card p-4 rounded-2xl border border-white/[0.08] shadow-xl z-20">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-xl bg-violet-500/15 flex items-center justify-center text-violet-400 text-lg">💰</div>
                  <div><p className="text-[10px] text-white/40 uppercase tracking-wider">Avg. Return</p><p className="text-lg font-bold text-white">12.4%</p></div>
                </div>
              </motion.div>
              <motion.div animate={{ y: [0, 8, 0] }} transition={{ repeat: Infinity, duration: 5, delay: 1 }}
                className="absolute -bottom-4 -left-8 glass-card p-4 rounded-2xl border border-white/[0.08] shadow-xl z-20">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-xl bg-emerald-500/15 flex items-center justify-center text-emerald-400 text-lg">🛡️</div>
                  <div><p className="text-[10px] text-white/40 uppercase tracking-wider">Default Rate</p><p className="text-lg font-bold text-white">&lt; 1.2%</p></div>
                </div>
              </motion.div>
            </motion.div>
          </div>
        </section>

        {/* ══════════ STATS ══════════ */}
        <section id="stats" className="relative py-20 border-y border-white/[0.04]">
          <div className="absolute inset-0 bg-gradient-to-b from-violet-500/[0.03] to-transparent pointer-events-none" />
          <div className="max-w-7xl mx-auto px-6 lg:px-12">
            <motion.div initial="hidden" whileInView="visible" viewport={{ once: true }} variants={fadeUp} transition={{ duration: 0.6 }}
              className="grid grid-cols-2 lg:grid-cols-4 gap-8">
              {[
                { value: '₹45Cr+', label: 'Total Funded', icon: '💎' },
                { value: '12,400+', label: 'Active Investors', icon: '👥' },
                { value: '12.4%', label: 'Avg. Returns', icon: '📈' },
                { value: '99.2%', label: 'Recovery Rate', icon: '🛡️' },
              ].map((stat, i) => (
                <div key={i} className="text-center">
                  <p className="text-3xl mb-2">{stat.icon}</p>
                  <p className="font-display text-3xl lg:text-4xl font-bold text-white mb-2">{stat.value}</p>
                  <p className="text-sm text-white/40">{stat.label}</p>
                </div>
              ))}
            </motion.div>
          </div>
        </section>

        {/* ══════════ FEATURES ══════════ */}
        <section id="features" className="py-28 max-w-7xl mx-auto px-6 lg:px-12">
          <motion.div initial="hidden" whileInView="visible" viewport={{ once: true }} variants={fadeUp} transition={{ duration: 0.6 }} className="text-center mb-16">
            <span className="text-xs font-semibold text-violet-400 uppercase tracking-widest mb-3 block">Why Choose Lenden</span>
            <h2 className="font-display text-3xl lg:text-5xl font-bold text-white mb-5">Built for the modern investor</h2>
            <p className="text-white/40 max-w-2xl mx-auto text-lg">Everything you need to manage micro-lending investments with confidence, security, and premium returns.</p>
          </motion.div>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {[
              { icon: '🔐', title: 'Bank-Grade Security', desc: '256-bit encryption, multi-factor authentication, and RBI-compliant KYC verification for every user.' },
              { icon: '📊', title: 'AI Risk Analysis', desc: 'Proprietary credit scoring algorithm assesses borrower risk with 97% accuracy, protecting your investments.' },
              { icon: '⚡', title: 'Instant Disbursement', desc: 'Approved loans are funded and disbursed within 24 hours. No red tape, no waiting.' },
              { icon: '🔄', title: 'Fractional Investing', desc: 'Diversify your portfolio by investing as little as ₹500 across multiple loan opportunities.' },
              { icon: '📈', title: 'Premium Returns', desc: 'Earn 10-18% annual returns, significantly outperforming traditional savings and fixed deposits.' },
              { icon: '🛡️', title: 'Collection Guarantee', desc: 'Our legal and recovery infrastructure ensures maximum repayment with minimal default rates.' },
            ].map((feat, i) => (
              <motion.div key={i} initial="hidden" whileInView="visible" viewport={{ once: true }} variants={fadeUp}
                transition={{ delay: i * 0.08, duration: 0.5 }}
                className="glass-card p-8 group hover:border-violet-500/20 transition-all duration-300 hover:shadow-glow-violet">
                <div className="w-14 h-14 rounded-2xl bg-violet-500/10 border border-violet-500/15 flex items-center justify-center text-2xl mb-6 
                               group-hover:bg-violet-500/20 group-hover:scale-110 transition-all duration-300">
                  {feat.icon}
                </div>
                <h3 className="text-lg font-bold text-white mb-3 font-display">{feat.title}</h3>
                <p className="text-white/40 leading-relaxed text-sm">{feat.desc}</p>
              </motion.div>
            ))}
          </div>
        </section>

        {/* ══════════ HOW IT WORKS ══════════ */}
        <section id="how-it-works" className="py-28 border-y border-white/[0.04] bg-gradient-to-b from-transparent via-violet-500/[0.02] to-transparent">
          <div className="max-w-7xl mx-auto px-6 lg:px-12">
            <motion.div initial="hidden" whileInView="visible" viewport={{ once: true }} variants={fadeUp} transition={{ duration: 0.6 }} className="text-center mb-16">
              <span className="text-xs font-semibold text-violet-400 uppercase tracking-widest mb-3 block">Simple Process</span>
              <h2 className="font-display text-3xl lg:text-5xl font-bold text-white mb-5">Start in 3 easy steps</h2>
              <p className="text-white/40 max-w-2xl mx-auto text-lg">From registration to your first investment in under 10 minutes.</p>
            </motion.div>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-8 relative">
              {/* Connecting Line */}
              <div className="hidden md:block absolute top-16 left-[17%] right-[17%] h-[1px] bg-gradient-to-r from-violet-500/30 via-indigo-500/30 to-blue-500/30" />
              {[
                { step: '01', title: 'Create & Verify', desc: 'Sign up with email or Google. Complete instant KYC with Aadhaar & PAN verification.', icon: '🔐' },
                { step: '02', title: 'Fund & Browse', desc: 'Add funds to your wallet. Browse curated loan opportunities with detailed risk analysis.', icon: '💰' },
                { step: '03', title: 'Earn & Track', desc: 'Invest fractionally across loans. Track returns, EMIs, and portfolio growth in real-time.', icon: '📈' },
              ].map((item, i) => (
                <motion.div key={i} initial="hidden" whileInView="visible" viewport={{ once: true }} variants={fadeUp}
                  transition={{ delay: i * 0.15, duration: 0.5 }} className="relative text-center">
                  <div className="w-14 h-14 rounded-2xl bg-gradient-primary flex items-center justify-center text-2xl mx-auto mb-6 relative z-10 shadow-glow-purple">
                    {item.icon}
                  </div>
                  <span className="text-[80px] font-display font-black text-white/[0.03] absolute top-[-20px] left-1/2 -translate-x-1/2 z-0 select-none">{item.step}</span>
                  <h3 className="text-xl font-bold text-white mb-3 font-display relative z-10">{item.title}</h3>
                  <p className="text-white/40 leading-relaxed relative z-10">{item.desc}</p>
                </motion.div>
              ))}
            </div>
          </div>
        </section>

        {/* ══════════ TESTIMONIALS ══════════ */}
        <section id="testimonials" className="py-28 max-w-7xl mx-auto px-6 lg:px-12">
          <motion.div initial="hidden" whileInView="visible" viewport={{ once: true }} variants={fadeUp} transition={{ duration: 0.6 }} className="text-center mb-16">
            <span className="text-xs font-semibold text-violet-400 uppercase tracking-widest mb-3 block">Testimonials</span>
            <h2 className="font-display text-3xl lg:text-5xl font-bold text-white mb-5">Loved by investors & borrowers</h2>
          </motion.div>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {[
              { name: 'Priya Sharma', role: 'Lender', text: `I have been earning 14% returns consistently for the past 8 months. Lenden's risk analysis is spot on.`, rating: 5 },
              { name: 'Rahul Verma', role: 'Borrower', text: 'Got my small business loan approved and funded within 48 hours. No bank would give me this speed.', rating: 5 },
              { name: 'Sneha Reddy', role: 'Lender', text: 'The fractional investing feature lets me spread risk across 20+ loans with just ₹50,000. Brilliant.', rating: 5 },
            ].map((t, i) => (
              <motion.div key={i} initial="hidden" whileInView="visible" viewport={{ once: true }} variants={fadeUp}
                transition={{ delay: i * 0.1, duration: 0.5 }} className="glass-card p-8">
                <div className="flex gap-1 mb-4">{Array(t.rating).fill(0).map((_, j) => <span key={j} className="text-amber-400">★</span>)}</div>
                <p className="text-white/60 leading-relaxed mb-6 text-sm">"{t.text}"</p>
                <div className="flex items-center gap-3 pt-4 border-t border-white/[0.06]">
                  <div className="w-10 h-10 rounded-full bg-gradient-primary flex items-center justify-center text-sm font-bold text-white">{t.name[0]}</div>
                  <div>
                    <p className="text-sm font-semibold text-white">{t.name}</p>
                    <p className="text-xs text-violet-400">{t.role}</p>
                  </div>
                </div>
              </motion.div>
            ))}
          </div>
        </section>

        {/* ══════════ CTA ══════════ */}
        <section className="py-28 relative">
          <div className="absolute inset-0 bg-gradient-to-b from-violet-500/[0.05] via-indigo-500/[0.03] to-transparent pointer-events-none" />
          <div className="max-w-3xl mx-auto px-6 text-center relative z-10">
            <motion.div initial="hidden" whileInView="visible" viewport={{ once: true }} variants={fadeUp} transition={{ duration: 0.6 }}>
              <h2 className="font-display text-4xl lg:text-5xl font-bold text-white mb-6">Ready to grow your wealth?</h2>
              <p className="text-white/40 text-lg mb-10">Join thousands of investors earning premium returns on India's most trusted P2P lending platform.</p>
              <div className="flex flex-col sm:flex-row gap-4 justify-center">
                <Link to="/signup" className="btn-gradient !py-4 !px-10 text-lg font-semibold shadow-glow-purple">
                  <span>Create Free Account</span>
                </Link>
                <Link to="/login" className="btn-outline !py-4 !px-10 text-lg">Sign In</Link>
              </div>
            </motion.div>
          </div>
        </section>
      </main>

      {/* ══════════ FOOTER ══════════ */}
      <footer className="relative z-10 border-t border-white/[0.06] bg-dark-950/50">
        <div className="max-w-7xl mx-auto px-6 lg:px-12 py-16">
          <div className="grid grid-cols-2 md:grid-cols-4 gap-10 mb-12">
            {/* Brand */}
            <div className="col-span-2 md:col-span-1">
              <div className="flex items-center gap-3 mb-5">
                <LendenLogo size={36} />
                <span className="font-display font-bold text-xl">Len<span className="text-violet-400">den</span></span>
              </div>
              <p className="text-sm text-white/30 leading-relaxed mb-4">India's leading P2P micro-lending platform connecting investors and borrowers for mutual growth.</p>
              <div className="flex gap-3">
                {['𝕏', 'in', 'f'].map((s, i) => (
                  <a key={i} href="#" className="w-8 h-8 rounded-lg bg-white/[0.04] border border-white/[0.06] flex items-center justify-center text-xs text-white/40 hover:text-white hover:border-violet-500/30 transition-all">
                    {s}
                  </a>
                ))}
              </div>
            </div>
            {/* Links */}
            {[
              { title: 'Platform', links: ['Marketplace', 'How it Works', 'Risk Analysis', 'FAQs'] },
              { title: 'Company', links: ['About Us', 'Careers', 'Press', 'Contact'] },
              { title: 'Legal', links: ['Terms of Service', 'Privacy Policy', 'KYC Policy', 'Grievance'] },
            ].map((col, i) => (
              <div key={i}>
                <h4 className="font-display font-semibold text-white text-sm mb-4">{col.title}</h4>
                <ul className="space-y-3">
                  {col.links.map((link, j) => (
                    <li key={j}><a href="#" className="text-sm text-white/30 hover:text-white/70 transition-colors">{link}</a></li>
                  ))}
                </ul>
              </div>
            ))}
          </div>
          {/* Bottom Bar */}
          <div className="pt-8 border-t border-white/[0.06] flex flex-col md:flex-row justify-between items-center gap-4">
            <p className="text-xs text-white/20">© 2026 Lenden Technologies Pvt. Ltd. All rights reserved. CIN: U74999MH2024PTC123456</p>
            <p className="text-xs text-white/20">Investments are subject to market risks. Returns are not guaranteed.</p>
          </div>
        </div>
      </footer>
    </div>
  );
};

export default Home;
