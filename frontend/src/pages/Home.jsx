import React from 'react';
import { motion } from 'framer-motion';
import { Link } from 'react-router-dom';

const Home = () => {
  return (
    <div className="min-h-screen bg-dark-900 text-white overflow-hidden font-sans">
      {/* Background Effects */}
      <div className="absolute inset-0 z-0">
        <div className="absolute top-[-10%] left-[-10%] w-[40%] h-[40%] bg-emerald-500/20 rounded-full blur-[120px] animate-pulse-slow" />
        <div className="absolute bottom-[-10%] right-[-10%] w-[40%] h-[40%] bg-cyan-500/20 rounded-full blur-[120px] animate-pulse-slow" style={{ animationDelay: '2s' }} />
        <div className="absolute top-[40%] left-[60%] w-[30%] h-[30%] bg-purple-500/10 rounded-full blur-[100px] animate-pulse-slow" style={{ animationDelay: '4s' }} />
      </div>

      {/* Public Navbar */}
      <nav className="relative z-10 flex items-center justify-between px-8 py-6 max-w-7xl mx-auto">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-gradient-primary flex items-center justify-center text-xl font-bold text-white shadow-glow-green">
            M
          </div>
          <span className="font-display font-bold text-2xl tracking-tight">MicroLend</span>
        </div>
        <div className="hidden md:flex items-center gap-8 text-sm font-medium text-white/70">
          <a href="#how-it-works" className="hover:text-white transition-colors">How it works</a>
          <a href="#benefits" className="hover:text-white transition-colors">Benefits</a>
          <a href="#stats" className="hover:text-white transition-colors">Statistics</a>
        </div>
        <div className="flex items-center gap-4">
          <Link to="/login" className="text-sm font-medium text-white/70 hover:text-white transition-colors">Sign In</Link>
          <Link to="/signup" className="btn-gradient !py-2.5 !px-6 text-sm">Get Started</Link>
        </div>
      </nav>

      <main className="relative z-10 max-w-7xl mx-auto px-8 pt-20 pb-32">
        {/* Hero Section */}
        <div className="flex flex-col lg:flex-row items-center gap-16">
          <div className="flex-1 text-center lg:text-left">
            <motion.div initial={{ opacity: 0, y: 30 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.6 }}>
              <span className="inline-block py-1 px-3 rounded-full bg-emerald-500/10 text-emerald-400 text-sm font-semibold mb-6 border border-emerald-500/20">
                🚀 Revolutionizing P2P Finance
              </span>
              <h1 className="font-display text-5xl lg:text-7xl font-bold leading-tight mb-6">
                Invest smartly. <br />
                <span className="text-transparent bg-clip-text bg-gradient-to-r from-emerald-400 to-cyan-400">
                  Borrow fairly.
                </span>
              </h1>
              <p className="text-lg text-white/50 mb-10 max-w-xl mx-auto lg:mx-0 leading-relaxed">
                Connect directly with verified borrowers to earn premium returns, or get funded instantly without traditional banking hurdles. The modern micro-lending platform built for everyone.
              </p>
              <div className="flex flex-col sm:flex-row items-center gap-4 justify-center lg:justify-start">
                <Link to="/signup" className="btn-gradient w-full sm:w-auto !py-4 !px-8 text-lg font-semibold shadow-glow-green">Start Investing</Link>
                <Link to="/signup" className="w-full sm:w-auto px-8 py-4 rounded-xl text-lg font-semibold text-white bg-dark-800 border border-white/10 hover:bg-white/5 transition-all">Apply for Loan</Link>
              </div>
            </motion.div>
          </div>

          {/* Hero Visual */}
          <motion.div initial={{ opacity: 0, scale: 0.9 }} animate={{ opacity: 1, scale: 1 }} transition={{ duration: 0.8, delay: 0.2 }} className="flex-1 relative w-full max-w-lg">
            <div className="relative z-10 glass-card p-6 border border-white/10 shadow-2xl">
              <div className="flex justify-between items-center mb-6">
                <div>
                  <p className="text-sm text-white/50 mb-1">Total Portfolio Value</p>
                  <p className="text-3xl font-bold font-display text-white">₹1,24,50,000</p>
                </div>
                <div className="w-12 h-12 rounded-full bg-emerald-500/20 flex items-center justify-center text-emerald-400 text-xl">📈</div>
              </div>
              <div className="space-y-4">
                {[
                  { title: 'Small Business Expansion', amount: '₹25,000', return: '12%', progress: 85 },
                  { title: 'Education Loan - MBA', amount: '₹50,000', return: '10%', progress: 100 },
                  { title: 'Farm Equipment', amount: '₹30,000', return: '14%', progress: 40 },
                ].map((loan, i) => (
                  <div key={i} className="p-4 rounded-xl bg-dark-800/50 border border-white/5 hover:bg-white/5 transition-colors">
                    <div className="flex justify-between mb-2">
                      <span className="font-medium text-sm text-white">{loan.title}</span>
                      <span className="text-sm font-semibold text-cyan-400">{loan.return} APR</span>
                    </div>
                    <div className="flex justify-between text-xs text-white/40 mb-2">
                      <span>{loan.amount}</span>
                      <span>{loan.progress}% Funded</span>
                    </div>
                    <div className="h-1.5 w-full bg-dark-600 rounded-full overflow-hidden">
                      <motion.div initial={{ width: 0 }} animate={{ width: `${loan.progress}%` }} transition={{ duration: 1.5, delay: 0.5 + (i * 0.2) }} className="h-full bg-gradient-to-r from-emerald-500 to-cyan-500 rounded-full" />
                    </div>
                  </div>
                ))}
              </div>
            </div>
            
            {/* Floating decorative elements */}
            <motion.div animate={{ y: [0, -10, 0] }} transition={{ repeat: Infinity, duration: 4 }} className="absolute -top-10 -right-10 glass-card p-4 rounded-2xl border border-white/10 shadow-xl z-20 backdrop-blur-md bg-dark-800/80">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-full bg-emerald-500/20 flex items-center justify-center text-emerald-400 text-lg">💰</div>
                <div><p className="text-xs text-white/50">Avg. Return</p><p className="text-lg font-bold text-white">12.4% p.a.</p></div>
              </div>
            </motion.div>
            <motion.div animate={{ y: [0, 10, 0] }} transition={{ repeat: Infinity, duration: 5 }} className="absolute -bottom-6 -left-10 glass-card p-4 rounded-2xl border border-white/10 shadow-xl z-20 backdrop-blur-md bg-dark-800/80">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-full bg-cyan-500/20 flex items-center justify-center text-cyan-400 text-lg">🛡️</div>
                <div><p className="text-xs text-white/50">Default Rate</p><p className="text-lg font-bold text-white">&lt; 1.2%</p></div>
              </div>
            </motion.div>
          </motion.div>
        </div>

        {/* Stats Section */}
        <motion.div id="stats" initial={{ opacity: 0, y: 30 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }} className="mt-32 grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="glass-card p-8 text-center border-t-2 border-t-emerald-500">
            <h3 className="font-display text-4xl font-bold text-white mb-2">₹4.5Cr+</h3>
            <p className="text-white/50">Total Funded Volume</p>
          </div>
          <div className="glass-card p-8 text-center border-t-2 border-t-cyan-500">
            <h3 className="font-display text-4xl font-bold text-white mb-2">12,400+</h3>
            <p className="text-white/50">Active Investors</p>
          </div>
          <div className="glass-card p-8 text-center border-t-2 border-t-purple-500">
            <h3 className="font-display text-4xl font-bold text-white mb-2">100%</h3>
            <p className="text-white/50">Identity Verified Users</p>
          </div>
        </motion.div>

        {/* How it Works */}
        <motion.div id="how-it-works" initial={{ opacity: 0, y: 30 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }} className="mt-32">
          <div className="text-center mb-16">
            <h2 className="font-display text-3xl lg:text-4xl font-bold text-white mb-4">How MicroLend Works</h2>
            <p className="text-white/50 max-w-2xl mx-auto">A seamless platform bridging the gap between individuals seeking capital and those looking to grow their wealth.</p>
          </div>
          
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            {[
              { step: '01', title: 'Create Account & KYC', desc: 'Sign up and complete our secure AI-driven verification process in minutes.', icon: '🔐' },
              { step: '02', title: 'Fund or Apply', desc: 'Lenders deposit funds. Borrowers submit loan requests with clear purpose details.', icon: '💸' },
              { step: '03', title: 'Earn & Repay', desc: 'Loans are funded fractionally. Borrowers repay monthly, lenders earn passive income.', icon: '📈' },
            ].map((item, i) => (
              <div key={i} className="relative p-8 rounded-3xl bg-dark-800/30 border border-white/5 hover:border-white/10 transition-colors">
                <span className="absolute -top-6 -left-6 text-7xl font-display font-bold text-white/5 z-0">{item.step}</span>
                <div className="relative z-10">
                  <div className="w-14 h-14 rounded-2xl bg-dark-700 flex items-center justify-center text-3xl mb-6 shadow-inner border border-white/5">{item.icon}</div>
                  <h3 className="text-xl font-bold text-white mb-3">{item.title}</h3>
                  <p className="text-white/50 leading-relaxed">{item.desc}</p>
                </div>
              </div>
            ))}
          </div>
        </motion.div>
      </main>
      
      {/* Footer */}
      <footer className="border-t border-white/5 bg-dark-900 py-12 px-8 relative z-10">
        <div className="max-w-7xl mx-auto flex flex-col md:flex-row justify-between items-center gap-6">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-lg bg-gradient-primary flex items-center justify-center text-sm font-bold text-white">M</div>
            <span className="font-display font-bold text-xl text-white/80">MicroLend</span>
          </div>
          <p className="text-white/30 text-sm">© 2026 MicroLend Platform. All rights reserved.</p>
        </div>
      </footer>
    </div>
  );
};

export default Home;
