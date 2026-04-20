import React from 'react';
import { motion } from 'framer-motion';
import { useNavigate } from 'react-router-dom';

const LoanCard = ({ loan, index = 0 }) => {
  const navigate = useNavigate();
  const progress = loan.amount > 0 ? (parseFloat(loan.funded_amount) / parseFloat(loan.amount)) * 100 : 0;

  const riskColors = {
    low: { bg: 'bg-emerald-500/10 border-emerald-500/15', text: 'text-emerald-400', bar: 'from-emerald-500 to-teal-500' },
    medium: { bg: 'bg-amber-500/10 border-amber-500/15', text: 'text-amber-400', bar: 'from-amber-500 to-orange-500' },
    high: { bg: 'bg-rose-500/10 border-rose-500/15', text: 'text-rose-400', bar: 'from-rose-500 to-pink-500' },
  };
  const risk = riskColors[loan.risk_score] || riskColors.medium;

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: index * 0.05, duration: 0.4 }}
      whileHover={{ y: -4, transition: { duration: 0.2 } }}
      onClick={() => navigate(`/loans/${loan.id}`)}
      className="glass-card p-6 cursor-pointer hover:border-violet-500/15 transition-all duration-300"
    >
      <div className="flex items-start justify-between mb-4">
        <div className="flex-1 min-w-0">
          <h3 className="font-semibold text-white truncate mb-1 font-display">{loan.title}</h3>
          <p className="text-xs text-white/30">by {loan.borrower_name || 'Anonymous'}</p>
        </div>
        <span className={`badge ${risk.bg} ${risk.text} uppercase ml-2 border`}>
          {loan.risk_score}
        </span>
      </div>

      <div className="grid grid-cols-2 gap-4 mb-4">
        <div>
          <p className="text-xs text-white/30 mb-1">Amount</p>
          <p className="text-lg font-bold text-white font-display">₹{parseFloat(loan.amount).toLocaleString('en-IN')}</p>
        </div>
        <div>
          <p className="text-xs text-white/30 mb-1">Interest</p>
          <p className="text-lg font-bold text-violet-400 font-display">{loan.interest_rate}%</p>
        </div>
      </div>

      <div className="mb-3">
        <div className="flex items-center justify-between mb-1.5">
          <span className="text-xs text-white/30">Funded</span>
          <span className="text-xs font-semibold text-white">{progress.toFixed(0)}%</span>
        </div>
        <div className="h-1.5 bg-white/[0.06] rounded-full overflow-hidden">
          <motion.div
            initial={{ width: 0 }}
            animate={{ width: `${progress}%` }}
            transition={{ duration: 1, delay: index * 0.05 + 0.3 }}
            className={`h-full rounded-full bg-gradient-to-r ${risk.bar}`}
          />
        </div>
      </div>

      <div className="flex items-center justify-between pt-3 border-t border-white/[0.04]">
        <span className="text-xs text-white/30">{loan.tenure_months}mo tenure</span>
        <span className="text-xs text-white/30">{loan.contributor_count || 0} investors</span>
      </div>
    </motion.div>
  );
};

export default LoanCard;
