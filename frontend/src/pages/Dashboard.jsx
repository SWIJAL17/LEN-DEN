import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
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
];

const Dashboard = () => {
  const { user, updateUser } = useAuth();
  const isLender = user?.role === 'lender';
  const isAdmin = user?.role === 'admin';
  const [loans, setLoans] = useState(demoLoans);
  const [activity, setActivity] = useState(demoActivity);
  const [stats, setStats] = useState(null);

  // Fetch real data from backend
  useEffect(() => {
    const fetchData = async () => {
      try {
        // Fetch user stats
        const statsRes = await userAPI.getStats();
        setStats(statsRes.data);

        // Fetch marketplace loans
        const loansRes = await loanAPI.getAll({ limit: 4 });
        if (loansRes.data.loans?.length > 0) setLoans(loansRes.data.loans);

        // Fetch wallet/transactions for activity
        const walletRes = await walletAPI.get();
        if (walletRes.data.transactions?.length > 0) {
          setActivity(walletRes.data.transactions.slice(0, 4).map(tx => ({
            type: tx.type,
            description: tx.description,
            amount: ['deposit', 'repayment_in', 'loan_disbursement'].includes(tx.type) ? tx.amount : -tx.amount,
            time: new Date(tx.created_at).toLocaleDateString('en-IN', { day: 'numeric', month: 'short' }),
            icon: tx.type === 'deposit' ? '💰' : tx.type.includes('repayment') ? '📥' : '📤',
          })));
        }

        // Update wallet balance in context
        if (walletRes.data.balance) {
          updateUser({ walletBalance: walletRes.data.balance });
        }
      } catch {
        // Backend not available — use demo data silently
      }
    };
    fetchData();
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  const borrowerStats = [
    { icon: '📋', label: 'Active Loans', value: stats?.total_loans || '3', color: 'emerald', trend: 12 },
    { icon: '💰', label: 'Total Borrowed', value: `₹${parseInt(stats?.total_borrowed || 75000).toLocaleString('en-IN')}`, color: 'cyan' },
    { icon: '✅', label: 'Repaid', value: `₹${parseInt(stats?.total_repaid || 42500).toLocaleString('en-IN')}`, color: 'purple', trend: 8 },
    { icon: '⚠️', label: 'Pending EMIs', value: stats?.overdue_count || '5', color: 'amber' },
  ];

  const lenderStats = [
    { icon: '💎', label: 'Total Invested', value: `₹${parseInt(stats?.total_invested || 125000).toLocaleString('en-IN')}`, color: 'emerald', trend: 15 },
    { icon: '📈', label: 'Expected Returns', value: `₹${parseInt(stats?.expected_returns || 14800).toLocaleString('en-IN')}`, color: 'cyan', trend: 8 },
    { icon: '✅', label: 'Returns Received', value: `₹${parseInt(stats?.total_returns || 8200).toLocaleString('en-IN')}`, color: 'purple' },
    { icon: '📊', label: 'Active Investments', value: stats?.total_investments || '7', color: 'amber' },
  ];

  const adminStats = [
    { icon: '👥', label: 'Total Users', value: stats?.total_users || '1,247', color: 'emerald', trend: 22 },
    { icon: '📋', label: 'Active Loans', value: stats?.active_loans || '89', color: 'cyan', trend: 5 },
    { icon: '💰', label: 'Platform Volume', value: `₹${parseInt(stats?.total_volume || 4500000).toLocaleString('en-IN')}`, color: 'purple', trend: 18 },
    { icon: '⏳', label: 'Pending Approvals', value: stats?.pending_loans || '12', color: 'amber' },
  ];

  const currentStats = isAdmin ? adminStats : isLender ? lenderStats : borrowerStats;

  return (
    <DashboardLayout title="Dashboard">
      {/* Welcome */}
      <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} className="mb-8">
        <h2 className="text-2xl font-display font-bold text-white mb-1">
          Good {new Date().getHours() < 12 ? 'Morning' : new Date().getHours() < 18 ? 'Afternoon' : 'Evening'}, {user?.name?.split(' ')[0]}! 👋
        </h2>
        <p className="text-white/40">Here's your financial overview</p>
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
          <h3 className="font-display font-semibold text-white mb-4">Recent Activity</h3>
          <div className="space-y-4">
            {activity.map((act, i) => (
              <motion.div key={i} initial={{ opacity: 0, x: -10 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: i * 0.1 }} className="flex items-center gap-3">
                <div className="w-9 h-9 rounded-lg bg-dark-600 flex items-center justify-center text-base shrink-0">{act.icon}</div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm text-white truncate">{act.description}</p>
                  <p className="text-xs text-white/30">{act.time}</p>
                </div>
                <span className={`text-sm font-semibold ${act.amount > 0 ? 'text-emerald-400' : 'text-rose-400'}`}>
                  {act.amount > 0 ? '+' : ''}₹{Math.abs(act.amount).toLocaleString('en-IN')}
                </span>
              </motion.div>
            ))}
          </div>
        </div>
      </div>

      {/* Featured Loans */}
      {!isAdmin && (
        <>
          <h3 className="font-display font-semibold text-white text-lg mb-4">
            {isLender ? 'Recommended for You' : 'Active Loans'}
          </h3>
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