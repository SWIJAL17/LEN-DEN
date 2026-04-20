import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import DashboardLayout from '../components/layout/DashboardLayout';
import { useAuth } from '../context/AuthContext';
import { loanAPI, investmentAPI } from '../services/api';

const demoBorrowerLoans = [
  { id: '1', title: 'Small Business Expansion', borrower_name: 'You', amount: 25000, funded_amount: 18000, interest_rate: 12, tenure_months: 12, risk_score: 'low', contributor_count: 4, status: 'approved' },
  { id: '2', title: 'Equipment Purchase', borrower_name: 'You', amount: 15000, funded_amount: 15000, interest_rate: 10, tenure_months: 6, risk_score: 'low', contributor_count: 3, status: 'active' },
  { id: '3', title: 'Marketing Campaign', borrower_name: 'You', amount: 10000, funded_amount: 0, interest_rate: 14, tenure_months: 12, risk_score: 'medium', contributor_count: 0, status: 'pending' },
];

const demoLenderInvestments = [
  { id: '4', title: 'Education Loan - MBA', borrower_name: 'Rahul Verma', amount: 50000, funded_amount: 50000, interest_rate: 10, tenure_months: 24, risk_score: 'low', contributor_count: 8, status: 'active', my_contribution: 5000, expected_return: 6100, actual_return: 1200 },
  { id: '5', title: 'Farm Equipment Purchase', borrower_name: 'Deepak Patel', amount: 30000, funded_amount: 30000, interest_rate: 11, tenure_months: 18, risk_score: 'low', contributor_count: 5, status: 'active', my_contribution: 8000, expected_return: 9440, actual_return: 3200 },
  { id: '6', title: 'Home Renovation', borrower_name: 'Meera Joshi', amount: 40000, funded_amount: 28000, interest_rate: 14, tenure_months: 12, risk_score: 'medium', contributor_count: 6, status: 'approved', my_contribution: 3000, expected_return: 3420, actual_return: 0 },
];

const statusBadge = {
  pending: 'bg-amber-500/10 text-amber-400',
  approved: 'bg-cyan-500/10 text-cyan-400',
  fully_funded: 'bg-emerald-500/10 text-emerald-400',
  active: 'bg-emerald-500/10 text-emerald-400',
  completed: 'bg-purple-500/10 text-purple-400',
  rejected: 'bg-rose-500/10 text-rose-400',
};

const MyLoans = () => {
  const { user } = useAuth();
  const isLender = user?.role === 'lender';
  const [data, setData] = useState(isLender ? demoLenderInvestments : demoBorrowerLoans);

  useEffect(() => {
    const fetchData = async () => {
      try {
        if (isLender) {
          const res = await investmentAPI.getMy();
          if (res.data.investments?.length > 0) setData(res.data.investments);
        } else {
          const res = await loanAPI.getMy();
          if (res.data.loans?.length > 0) setData(res.data.loans);
        }
      } catch {
        // Use demo data
      }
    };
    fetchData();
  }, [isLender]);

  return (
    <DashboardLayout title={isLender ? 'My Investments' : 'My Loans'}>
      <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} className="mb-8">
        <h2 className="text-2xl font-display font-bold text-white mb-1">
          {isLender ? 'Investment Portfolio' : 'Your Loan Requests'}
        </h2>
        <p className="text-white/40">
          {isLender ? 'Track your investments and returns' : 'Manage your loan applications'}
        </p>
      </motion.div>

      {/* Summary for lenders */}
      {isLender && (
        <div className="grid grid-cols-1 md:grid-cols-3 gap-5 mb-8">
          <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} className="glass-card p-6">
            <p className="text-sm text-white/40 mb-1">Total Invested</p>
            <p className="text-2xl font-bold text-white">₹16,000</p>
          </motion.div>
          <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.1 }} className="glass-card p-6">
            <p className="text-sm text-white/40 mb-1">Expected Returns</p>
            <p className="text-2xl font-bold text-emerald-400">₹18,960</p>
          </motion.div>
          <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.2 }} className="glass-card p-6">
            <p className="text-sm text-white/40 mb-1">Returns Received</p>
            <p className="text-2xl font-bold text-cyan-400">₹4,400</p>
          </motion.div>
        </div>
      )}

      {/* Loan/Investment List */}
      <div className="space-y-4">
        {data.map((item, i) => (
          <motion.div key={item.id} initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.05 }}
            className="glass-card-hover p-6 cursor-pointer">
            <div className="flex flex-col md:flex-row md:items-center gap-4">
              <div className="flex-1">
                <div className="flex items-center gap-3 mb-2">
                  <h3 className="font-semibold text-white">{item.title}</h3>
                  <span className={`badge ${statusBadge[item.status]} uppercase text-xs`}>{item.status.replace('_', ' ')}</span>
                </div>
                {isLender && <p className="text-xs text-white/40">Borrower: {item.borrower_name}</p>}
                <div className="flex flex-wrap gap-4 mt-3 text-sm">
                  <span className="text-white/50">Amount: <span className="text-white font-semibold">₹{parseFloat(item.amount).toLocaleString('en-IN')}</span></span>
                  <span className="text-white/50">Rate: <span className="text-cyan-400">{item.interest_rate}%</span></span>
                  {isLender && <span className="text-white/50">My Share: <span className="text-emerald-400 font-semibold">₹{item.my_contribution?.toLocaleString('en-IN')}</span></span>}
                </div>
              </div>
              <div className="flex items-center gap-4">
                {/* Mini Progress */}
                <div className="w-32">
                  <div className="flex justify-between text-xs mb-1">
                    <span className="text-white/30">Funded</span>
                    <span className="text-white/50">{((parseFloat(item.funded_amount) / parseFloat(item.amount)) * 100).toFixed(0)}%</span>
                  </div>
                  <div className="h-1.5 bg-dark-600 rounded-full overflow-hidden">
                    <div className="h-full bg-emerald-500 rounded-full" style={{ width: `${(parseFloat(item.funded_amount) / parseFloat(item.amount)) * 100}%` }} />
                  </div>
                </div>
              </div>
            </div>
          </motion.div>
        ))}
      </div>
    </DashboardLayout>
  );
};

export default MyLoans;
