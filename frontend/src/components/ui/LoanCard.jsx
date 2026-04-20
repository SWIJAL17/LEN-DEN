import React from 'react';
import { motion } from 'framer-motion';
import { useNavigate } from 'react-router-dom';

const LoanCard = ({ loan, index = 0 }) => {
  const navigate = useNavigate();
  const progress = loan.amount > 0 ? (parseFloat(loan.funded_amount) / parseFloat(loan.amount)) * 100 : 0;

  const riskColors = {
    low: { bg: 'bg-emerald-500/10', text: 'text-emerald-400', bar: 'bg-emerald-500' },
    medium: { bg: 'bg-amber-500/10', text: 'text-amber-400', bar: 'bg-amber-500' },
    high: { bg: 'bg-rose-500/10', text: 'text-rose-400', bar: 'bg-rose-500' },
  };
  const risk = riskColors[loan.risk_score] || riskColors.medium;

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: index * 0.05, duration: 0.4 }}
      onClick={() => navigate(`/loans/${loan.id}`)}
      className="glass-card-hover p-6 cursor-pointer"
    >
      {/* Header */}
      <div className="flex items-start justify-between mb-4">
        <div className="flex-1 min-w-0">
          <h3 className="font-semibold text-white truncate mb-1">{loan.title}</h3>
          <p className="text-xs text-white/40">by {loan.borrower_name || 'Anonymous'}</p>
        </div>
        <span className={`badge ${risk.bg} ${risk.text} uppercase ml-2`}>
          {loan.risk_score}
        </span>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 gap-4 mb-4">
        <div>
          <p className="text-xs text-white/40 mb-1">Amount</p>
          <p className="text-lg font-bold text-white">₹{parseFloat(loan.amount).toLocaleString('en-IN')}</p>
        </div>
        <div>
          <p className="text-xs text-white/40 mb-1">Interest</p>
          <p className="text-lg font-bold text-cyan-400">{loan.interest_rate}%</p>
        </div>
      </div>

      {/* Progress */}
      <div className="mb-3">
        <div className="flex items-center justify-between mb-1.5">
          <span className="text-xs text-white/40">Funded</span>
          <span className="text-xs font-semibold text-white">{progress.toFixed(0)}%</span>
        </div>
        <div className="h-2 bg-dark-600 rounded-full overflow-hidden">
          <motion.div
            initial={{ width: 0 }}
            animate={{ width: `${progress}%` }}
            transition={{ duration: 1, delay: index * 0.05 + 0.3 }}
            className={`h-full rounded-full ${risk.bar}`}
          />
        </div>
      </div>

      {/* Footer */}
      <div className="flex items-center justify-between pt-3 border-t border-white/5">
        <span className="text-xs text-white/40">{loan.tenure_months}mo tenure</span>
        <span className="text-xs text-white/40">{loan.contributor_count || 0} investors</span>
      </div>
    </motion.div>
  );
};

export default LoanCard;
