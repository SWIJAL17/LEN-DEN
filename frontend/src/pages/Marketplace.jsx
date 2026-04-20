import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import DashboardLayout from '../components/layout/DashboardLayout';
import LoanCard from '../components/ui/LoanCard';
import { loanAPI } from '../services/api';

const demoLoans = [
  { id: '1', title: 'Small Business Expansion', borrower_name: 'Priya Sharma', amount: 25000, funded_amount: 18000, interest_rate: 12, tenure_months: 12, risk_score: 'low', contributor_count: 4 },
  { id: '2', title: 'Education Loan - MBA', borrower_name: 'Rahul Verma', amount: 50000, funded_amount: 50000, interest_rate: 10, tenure_months: 24, risk_score: 'low', contributor_count: 8 },
  { id: '3', title: 'Medical Emergency Fund', borrower_name: 'Anita Desai', amount: 15000, funded_amount: 5000, interest_rate: 15, tenure_months: 6, risk_score: 'medium', contributor_count: 2 },
  { id: '4', title: 'Tech Startup Seed Round', borrower_name: 'Vikram Singh', amount: 100000, funded_amount: 35000, interest_rate: 18, tenure_months: 36, risk_score: 'high', contributor_count: 5 },
  { id: '5', title: 'Farm Equipment Purchase', borrower_name: 'Deepak Patel', amount: 30000, funded_amount: 12000, interest_rate: 11, tenure_months: 18, risk_score: 'low', contributor_count: 3 },
  { id: '6', title: 'Home Renovation', borrower_name: 'Meera Joshi', amount: 40000, funded_amount: 28000, interest_rate: 14, tenure_months: 12, risk_score: 'medium', contributor_count: 6 },
  { id: '7', title: 'Wedding Expenses', borrower_name: 'Arjun Nair', amount: 75000, funded_amount: 10000, interest_rate: 16, tenure_months: 24, risk_score: 'medium', contributor_count: 2 },
  { id: '8', title: 'E-commerce Inventory', borrower_name: 'Sneha Reddy', amount: 60000, funded_amount: 60000, interest_rate: 13, tenure_months: 12, risk_score: 'low', contributor_count: 10 },
  { id: '9', title: 'Vehicle Purchase', borrower_name: 'Karan Malhotra', amount: 200000, funded_amount: 45000, interest_rate: 20, tenure_months: 48, risk_score: 'high', contributor_count: 4 },
];

const Marketplace = () => {
  const [filter, setFilter] = useState('all');
  const [sort, setSort] = useState('newest');
  const [allLoans, setAllLoans] = useState(demoLoans);

  useEffect(() => {
    const fetchLoans = async () => {
      try {
        const res = await loanAPI.getAll({ limit: 50 });
        if (res.data.loans?.length > 0) setAllLoans(res.data.loans);
      } catch {
        // Use demo data
      }
    };
    fetchLoans();
  }, []);

  const filtered = allLoans.filter(l => filter === 'all' || l.risk_score === filter);
  const sorted = [...filtered].sort((a, b) => {
    if (sort === 'interest_high') return b.interest_rate - a.interest_rate;
    if (sort === 'interest_low') return a.interest_rate - b.interest_rate;
    if (sort === 'amount_high') return b.amount - a.amount;
    return 0;
  });

  return (
    <DashboardLayout title="Loan Marketplace">
      <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} className="mb-8">
        <h2 className="text-2xl font-display font-bold text-white mb-1">Explore Opportunities</h2>
        <p className="text-white/40">Browse and invest in vetted loan requests</p>
      </motion.div>

      {/* Filters */}
      <div className="flex flex-wrap items-center gap-3 mb-8">
        <div className="flex items-center gap-2 p-1 rounded-xl bg-dark-700/50 border border-white/5">
          {['all', 'low', 'medium', 'high'].map(f => (
            <button key={f} onClick={() => setFilter(f)}
              className={`px-4 py-2 rounded-lg text-sm font-medium transition-all capitalize
                ${filter === f ? 'bg-gradient-primary text-white' : 'text-white/40 hover:text-white'}`}>
              {f === 'all' ? 'All Risks' : f}
            </button>
          ))}
        </div>
        <select value={sort} onChange={e => setSort(e.target.value)}
          className="input-dark !w-auto !py-2 text-sm"
        >
          <option value="newest">Newest First</option>
          <option value="interest_high">Highest Interest</option>
          <option value="interest_low">Lowest Interest</option>
          <option value="amount_high">Highest Amount</option>
        </select>

        {/* Summary Stats */}
        <div className="ml-auto flex items-center gap-4">
          <div className="text-sm text-white/40">
            <span className="text-white font-semibold">{sorted.length}</span> loans available
          </div>
        </div>
      </div>

      {/* Loan Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
        {sorted.map((loan, i) => (
          <LoanCard key={loan.id} loan={loan} index={i} />
        ))}
      </div>

      {sorted.length === 0 && (
        <div className="text-center py-20">
          <p className="text-4xl mb-4">🔍</p>
          <p className="text-white/40 text-lg">No loans match your filters</p>
        </div>
      )}
    </DashboardLayout>
  );
};

export default Marketplace;
