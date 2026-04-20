import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { Link, useNavigate } from 'react-router-dom';
import DashboardLayout from '../components/layout/DashboardLayout';
import StatCard from '../components/ui/StatCard';
import EarningsChart from '../components/charts/EarningsChart';
import LoanCard from '../components/ui/LoanCard';
import { useAuth } from '../context/AuthContext';
import { userAPI, loanAPI, walletAPI } from '../services/api';

// Demo fallback data
const demoLoans = [
  { id: '1', title: 'Small Business Expansion', borrower_name: 'Priya Sharma', amount: 25000, funded_amount: 18000, interest_rate: 12, tenure_months: 12, risk_score: 'low', contributor_count: 4, status: 'approved' },
  { id: '2', title: 'Education Loan', borrower_name: 'Rahul Verma', amount: 50000, funded_amount: 50000, interest_rate: 10, tenure_months: 24, risk_score: 'low', contributor_count: 8, status: 'fully_funded' },
  { id: '3', title: 'Medical Emergency', borrower_name: 'Anita Desai', amount: 15000, funded_amount: 5000, interest_rate: 15, tenure_months: 6, risk_score: 'medium', contributor_count: 2, status: 'approved' },
  { id: '4', title: 'Tech Startup Seed', borrower_name: 'Vikram Singh', amount: 100000, funded_amount: 35000, interest_rate: 18, tenure_months: 36, risk_score: 'high', contributor_count: 5, status: 'approved' },
];

const demoActivity = [
  { type: 'deposit', description: 'Wallet deposit', amount: 5000, time: '2 hours ago', icon: '💰' },
  { type: 'loan_funding', description: 'Funded "Education Loan"', amount: -2000, time: '5 hours ago', icon: '📤' },
  { type: 'repayment_in', description: 'Repayment from Priya', amount: 1250, time: '1 day ago', icon: '📥' },
  { type: 'loan_funding', description: 'Funded "Small Business"', amount: -3000, time: '2 days ago', icon: '📤' },
  { type: 'deposit', description: 'Initial deposit', amount: 20000, time: '5 days ago', icon: '💰' },
];

const Dashboard = () => {
  const { user, updateUser } = useAuth();
  const navigate = useNavigate();
  const isLender = user?.role === 'lender';
  const isAdmin = user?.role === 'admin';
  const [loans, setLoans] = useState(demoLoans);
  const [activity, setActivity] = useState(demoActivity);
  const [stats, setStats] = useState(null);

  // Fetch real data from backend
  useEffect(() => {
    const fetchData = async () => {
      try {
        const statsRes = await userAPI.getStats();
        setStats(statsRes.data);
        const loansRes = await loanAPI.getAll({ limit: 4 });
        if (loansRes.data.loans?.length > 0) setLoans(loansRes.data.loans);
        const walletRes = await walletAPI.get();
        if (walletRes.data.transactions?.length > 0) {
          setActivity(walletRes.data.transactions.slice(0, 5).map(tx => ({
            type: tx.type,
            description: tx.description,
            amount: ['deposit', 'repayment_in', 'loan_disbursement'].includes(tx.type) ? tx.amount : -tx.amount,
            time: new Date(tx.created_at).toLocaleDateString('en-IN', { day: 'numeric', month: 'short' }),
            icon: tx.type === 'deposit' ? '💰' : tx.type.includes('repayment') ? '📥' : '📤',
          })));
        }
        if (walletRes.data.balance) updateUser({ walletBalance: walletRes.data.balance });
      } catch {
        // Backend not available — use demo data
      }
    };
    fetchData();
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  const borrowerStats = [
    { icon: '📋', label: 'Active Loans', value: stats?.total_loans || '3', color: 'violet', trend: 12 },
    { icon: '💰', label: 'Total Borrowed', value: `₹${parseInt(stats?.total_borrowed || 75000).toLocaleString('en-IN')}`, color: 'blue' },
    { icon: '✅', label: 'Repaid', value: `₹${parseInt(stats?.total_repaid || 42500).toLocaleString('en-IN')}`, color: 'emerald', trend: 8 },
    { icon: '⚠️', label: 'Pending EMIs', value: stats?.overdue_count || '5', color: 'amber' },
  ];

  const lenderStats = [
    { icon: '💎', label: 'Total Invested', value: `₹${parseInt(stats?.total_invested || 125000).toLocaleString('en-IN')}`, color: 'violet', trend: 15 },
    { icon: '📈', label: 'Expected Returns', value: `₹${parseInt(stats?.expected_returns || 14800).toLocaleString('en-IN')}`, color: 'blue', trend: 8 },
    { icon: '✅', label: 'Returns Received', value: `₹${parseInt(stats?.total_returns || 8200).toLocaleString('en-IN')}`, color: 'emerald' },
    { icon: '📊', label: 'Active Investments', value: stats?.total_investments || '7', color: 'amber' },
  ];

  const adminStats = [
    { icon: '👥', label: 'Total Users', value: stats?.total_users || '1,247', color: 'violet', trend: 22 },
    { icon: '📋', label: 'Active Loans', value: stats?.active_loans || '89', color: 'blue', trend: 5 },
    { icon: '💰', label: 'Platform Volume', value: `₹${parseInt(stats?.total_volume || 4500000).toLocaleString('en-IN')}`, color: 'emerald', trend: 18 },
    { icon: '⏳', label: 'Pending Approvals', value: stats?.pending_loans || '12', color: 'amber' },
  ];

  const currentStats = isAdmin ? adminStats : isLender ? lenderStats : borrowerStats;

  const quickActions = isLender ? [
    { label: 'Browse Loans', icon: '🔍', path: '/marketplace', color: 'violet' },
    { label: 'My Investments', icon: '📈', path: '/my-loans', color: 'blue' },
    { label: 'Add Funds', icon: '💰', path: '/wallet', color: 'emerald' },
  ] : isAdmin ? [
    { label: 'Manage Users', icon: '👥', path: '/admin', color: 'violet' },
    { label: 'Pending Loans', icon: '📋', path: '/admin', color: 'amber' },
    { label: 'Marketplace', icon: '🏪', path: '/marketplace', color: 'blue' },
  ] : [
    { label: 'Apply for Loan', icon: '➕', path: '/create-loan', color: 'violet' },
    { label: 'My Loans', icon: '📋', path: '/my-loans', color: 'blue' },
    { label: 'Deposit Funds', icon: '💰', path: '/wallet', color: 'emerald' },
  ];

  const colorMap = {
    violet: 'bg-violet-500/10 border-violet-500/20 text-violet-400 hover:bg-violet-500/20',
    blue: 'bg-blue-500/10 border-blue-500/20 text-blue-400 hover:bg-blue-500/20',
    emerald: 'bg-emerald-500/10 border-emerald-500/20 text-emerald-400 hover:bg-emerald-500/20',
    amber: 'bg-amber-500/10 border-amber-500/20 text-amber-400 hover:bg-amber-500/20',
  };

  return (
    <DashboardLayout title="Dashboard">
      {/* Welcome */}
      <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} className="mb-8 flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4">
        <div>
          <h2 className="text-2xl font-display font-bold text-white mb-1">
            Good {new Date().getHours() < 12 ? 'Morning' : new Date().getHours() < 18 ? 'Afternoon' : 'Evening'}, {user?.name?.split(' ')[0]}! 👋
          </h2>
          <p className="text-white/35">Here's your financial overview for today</p>
        </div>
        {/* Quick Actions */}
        <div className="flex gap-2">
          {quickActions.map((action, i) => (
            <motion.button key={i} whileHover={{ scale: 1.03, y: -2 }} whileTap={{ scale: 0.97 }}
              onClick={() => navigate(action.path)}
              className={`flex items-center gap-2 px-4 py-2.5 rounded-xl text-sm font-medium border transition-all ${colorMap[action.color]}`}>
              <span>{action.icon}</span>
              <span className="hidden sm:inline">{action.label}</span>
            </motion.button>
          ))}
        </div>
      </motion.div>

      {/* Stat Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5 mb-8">
        {currentStats.map((stat, i) => (
          <StatCard key={i} {...stat} delay={i} />
        ))}
      </div>

      {/* Chart + Activity */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
        <div className="lg:col-span-2">
          <EarningsChart />
        </div>
        <div className="glass-card p-6">
          <div className="flex items-center justify-between mb-5">
            <h3 className="font-display font-semibold text-white">Recent Activity</h3>
            <Link to="/wallet" className="text-xs text-violet-400 hover:text-violet-300 transition-colors">View All →</Link>
          </div>
          <div className="space-y-3">
            {activity.map((act, i) => (
              <motion.div key={i} initial={{ opacity: 0, x: -10 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: i * 0.08 }}
                className="flex items-center gap-3 p-3 rounded-xl hover:bg-white/[0.02] transition-colors">
                <div className="w-9 h-9 rounded-xl bg-white/[0.04] border border-white/[0.06] flex items-center justify-center text-base shrink-0">{act.icon}</div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm text-white truncate">{act.description}</p>
                  <p className="text-xs text-white/25">{act.time}</p>
                </div>
                <span className={`text-sm font-semibold ${act.amount > 0 ? 'text-emerald-400' : 'text-rose-400'}`}>
                  {act.amount > 0 ? '+' : ''}₹{Math.abs(act.amount).toLocaleString('en-IN')}
                </span>
              </motion.div>
            ))}
          </div>
        </div>
      </div>

      {/* Wallet Quick-Deposit Banner (for non-admin) */}
      {!isAdmin && (
        <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.3 }}
          className="glass-card p-6 mb-8 flex flex-col sm:flex-row items-center justify-between gap-4 border border-violet-500/10">
          <div className="flex items-center gap-4">
            <div className="w-12 h-12 rounded-2xl bg-violet-500/10 border border-violet-500/15 flex items-center justify-center text-2xl">💳</div>
            <div>
              <p className="font-semibold text-white">Wallet Balance: <span className="text-violet-400">₹{parseFloat(user?.walletBalance || 0).toLocaleString('en-IN')}</span></p>
              <p className="text-sm text-white/30">{isLender ? 'Add funds to start investing in loan opportunities' : 'Keep your wallet funded for timely EMI payments'}</p>
            </div>
          </div>
          <motion.button whileHover={{ scale: 1.03 }} whileTap={{ scale: 0.97 }} onClick={() => navigate('/wallet')}
            className="btn-gradient !py-3 !px-6 text-sm shrink-0">
            <span>{isLender ? 'Add Funds' : 'Manage Wallet'}</span>
          </motion.button>
        </motion.div>
      )}

      {/* Featured Loans */}
      {!isAdmin && (
        <>
          <div className="flex items-center justify-between mb-5">
            <h3 className="font-display font-semibold text-white text-lg">
              {isLender ? '🔥 Top Opportunities' : '📋 Your Active Loans'}
            </h3>
            <Link to="/marketplace" className="text-sm text-violet-400 hover:text-violet-300 font-medium transition-colors">
              View All →
            </Link>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-5">
            {loans.map((loan, i) => (
              <LoanCard key={loan.id} loan={loan} index={i} />
            ))}
          </div>
        </>
      )}
    </DashboardLayout>
  );
};

export default Dashboard;