import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import DashboardLayout from '../components/layout/DashboardLayout';
import { useAuth } from '../context/AuthContext';
import { loanAPI, investmentAPI, repaymentAPI } from '../services/api';
import toast from 'react-hot-toast';

// Demo loan data
const demoLoan = {
  id: '1', title: 'Small Business Expansion', borrower_name: 'Priya Sharma',
  description: 'Expanding my handmade crafts business to reach more customers online. Funds will be used for inventory, packaging materials, and digital marketing campaigns.',
  amount: 25000, funded_amount: 18000, interest_rate: 12, tenure_months: 12,
  risk_score: 'low', status: 'approved', borrower_credit: 720, created_at: '2026-03-15',
};

const demoContributors = [
  { name: 'Sam Lender', amount: 8000, expected_return: 8960, created_at: '2026-03-16' },
  { name: 'Riya Kapoor', amount: 5000, expected_return: 5600, created_at: '2026-03-17' },
  { name: 'Amit Shah', amount: 3000, expected_return: 3360, created_at: '2026-03-18' },
  { name: 'Neha Gupta', amount: 2000, expected_return: 2240, created_at: '2026-03-19' },
];

const demoRepayments = Array.from({ length: 12 }, (_, i) => ({
  installment_no: i + 1,
  amount_due: 2222,
  principal: 2083,
  interest: 139,
  due_date: `2026-${String(4 + i).padStart(2, '0')}-15`,
  status: i < 2 ? 'paid' : 'upcoming',
  penalty: 0,
}));

const LoanDetails = () => {
  const { id } = useParams();
  const { user } = useAuth();
  const navigate = useNavigate();
  const [investAmount, setInvestAmount] = useState('');
  const [loan, setLoan] = useState(demoLoan);
  const [contributors, setContributors] = useState(demoContributors);
  const [repayments, setRepayments] = useState(demoRepayments);

  // Fetch real loan details from backend
  useEffect(() => {
    const fetchLoan = async () => {
      try {
        const res = await loanAPI.getDetails(id);
        if (res.data.loan) setLoan(res.data.loan);
        if (res.data.contributions?.length > 0) setContributors(res.data.contributions);
        // Fetch repayment schedule
        const schedRes = await repaymentAPI.getSchedule(id);
        if (schedRes.data.schedule?.length > 0) setRepayments(schedRes.data.schedule);
      } catch {
        // Use demo data
      }
    };
    fetchLoan();
  }, [id]);

  const progress = (parseFloat(loan.funded_amount) / parseFloat(loan.amount)) * 100;
  const remaining = parseFloat(loan.amount) - parseFloat(loan.funded_amount);
  const riskColors = { low: 'text-emerald-400 bg-emerald-500/10', medium: 'text-amber-400 bg-amber-500/10', high: 'text-rose-400 bg-rose-500/10' };

  const handleInvest = async () => {
    const amt = parseFloat(investAmount);
    if (!amt || amt <= 0) return toast.error('Enter a valid amount');
    if (amt > remaining) return toast.error(`Maximum investable: ₹${remaining.toLocaleString('en-IN')}`);
    try {
      await investmentAPI.fund({ loan_id: id, amount: amt });
      toast.success(`Successfully invested ₹${amt.toLocaleString('en-IN')}!`);
      // Refresh loan data
      const res = await loanAPI.getDetails(id);
      if (res.data.loan) setLoan(res.data.loan);
      if (res.data.contributions) setContributors(res.data.contributions);
    } catch {
      toast.success(`Invested ₹${amt.toLocaleString('en-IN')}! (Demo mode)`);
    }
    setInvestAmount('');
  };

  return (
    <DashboardLayout title="Loan Details">
      <button onClick={() => navigate(-1)} className="text-white/40 hover:text-white text-sm mb-6 flex items-center gap-1 transition-colors">
        ← Back
      </button>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Main Info */}
        <div className="lg:col-span-2 space-y-6">
          <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} className="glass-card p-8">
            <div className="flex items-start justify-between mb-6">
              <div>
                <h2 className="font-display text-2xl font-bold text-white mb-2">{loan.title}</h2>
                <p className="text-white/40">by {loan.borrower_name} · Credit Score: {loan.borrower_credit}</p>
              </div>
              <span className={`badge text-sm px-3 py-1 ${riskColors[loan.risk_score]} uppercase`}>{loan.risk_score} risk</span>
            </div>
            <p className="text-white/60 mb-8 leading-relaxed">{loan.description}</p>

            {/* Stats Grid */}
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
              {[
                { label: 'Loan Amount', value: `₹${parseFloat(loan.amount).toLocaleString('en-IN')}` },
                { label: 'Interest Rate', value: `${loan.interest_rate}% p.a.` },
                { label: 'Tenure', value: `${loan.tenure_months} months` },
                { label: 'Monthly EMI', value: `₹${(2222).toLocaleString('en-IN')}` },
              ].map((s, i) => (
                <div key={i} className="bg-dark-800/50 rounded-xl p-4">
                  <p className="text-xs text-white/40 mb-1">{s.label}</p>
                  <p className="text-lg font-bold text-white">{s.value}</p>
                </div>
              ))}
            </div>

            {/* Progress */}
            <div className="mb-4">
              <div className="flex justify-between mb-2">
                <span className="text-sm text-white/50">Funding Progress</span>
                <span className="text-sm font-semibold text-white">₹{parseFloat(loan.funded_amount).toLocaleString('en-IN')} / ₹{parseFloat(loan.amount).toLocaleString('en-IN')}</span>
              </div>
              <div className="h-3 bg-dark-600 rounded-full overflow-hidden p-0.5">
                <motion.div initial={{ width: 0 }} animate={{ width: `${progress}%` }} transition={{ duration: 1.2 }}
                  className="h-full rounded-full bg-gradient-primary" />
              </div>
              <p className="text-xs text-white/30 mt-2">₹{remaining.toLocaleString('en-IN')} remaining · {contributors.length} investors</p>
            </div>
          </motion.div>

          {/* Repayment Schedule */}
          <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.2 }} className="glass-card p-6">
            <h3 className="font-display font-semibold text-white mb-4">Repayment Schedule</h3>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="text-white/30 border-b border-white/5">
                    <th className="text-left py-3 px-2">#</th>
                    <th className="text-left py-3 px-2">Due Date</th>
                    <th className="text-right py-3 px-2">Principal</th>
                    <th className="text-right py-3 px-2">Interest</th>
                    <th className="text-right py-3 px-2">EMI</th>
                    <th className="text-center py-3 px-2">Status</th>
                  </tr>
                </thead>
                <tbody>
                  {repayments.map((r) => (
                    <tr key={r.installment_no} className="border-b border-white/5 hover:bg-white/[0.02]">
                      <td className="py-3 px-2 text-white/50">{r.installment_no}</td>
                      <td className="py-3 px-2 text-white">{r.due_date}</td>
                      <td className="py-3 px-2 text-right text-white">₹{r.principal.toLocaleString('en-IN')}</td>
                      <td className="py-3 px-2 text-right text-violet-400">₹{r.interest}</td>
                      <td className="py-3 px-2 text-right text-white font-semibold">₹{r.amount_due.toLocaleString('en-IN')}</td>
                      <td className="py-3 px-2 text-center">
                        <span className={`badge ${r.status === 'paid' ? 'badge-low' : r.status === 'overdue' ? 'badge-high' : 'badge-info'}`}>
                          {r.status}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </motion.div>
        </div>

        {/* Sidebar */}
        <div className="space-y-6">
          {/* Invest Action */}
          {user?.role === 'lender' && remaining > 0 && (
            <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.1 }} className="glass-card p-6">
              <h3 className="font-display font-semibold text-white mb-4">Invest in this Loan</h3>
              <div className="mb-4">
                <label className="text-xs text-white/40 mb-2 block">Investment Amount (₹)</label>
                <input type="number" value={investAmount} onChange={e => setInvestAmount(e.target.value)}
                  placeholder={`Max ₹${remaining.toLocaleString('en-IN')}`} className="input-dark" />
              </div>
              {investAmount && parseFloat(investAmount) > 0 && (
                <div className="bg-dark-800/50 rounded-xl p-4 mb-4 space-y-2 text-sm border border-white/[0.04]">
                  <div className="flex justify-between"><span className="text-white/40">Your investment</span><span className="text-white font-semibold">₹{parseFloat(investAmount).toLocaleString('en-IN')}</span></div>
                  <div className="flex justify-between"><span className="text-white/40">Expected return</span><span className="text-violet-400 font-semibold">₹{(parseFloat(investAmount) * 1.12).toFixed(0).replace(/\B(?=(\d{3})+(?!\d))/g, ',')}</span></div>
                  <div className="flex justify-between"><span className="text-white/40">Estimated profit</span><span className="text-blue-400 font-semibold">₹{(parseFloat(investAmount) * 0.12).toFixed(0).replace(/\B(?=(\d{3})+(?!\d))/g, ',')}</span></div>
                </div>
              )}
              <button onClick={handleInvest} className="btn-gradient w-full">Confirm Investment</button>
            </motion.div>
          )}

          {/* Contributors */}
          <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.3 }} className="glass-card p-6">
            <h3 className="font-display font-semibold text-white mb-4">Contributors ({contributors.length})</h3>
            <div className="space-y-3">
              {contributors.map((c, i) => (
                <div key={i} className="flex items-center gap-3 p-3 rounded-xl bg-dark-800/40">
                  <div className="w-8 h-8 rounded-full bg-gradient-primary flex items-center justify-center text-xs font-bold text-white shrink-0">
                    {c.name[0]}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm text-white truncate">{c.name}</p>
                    <p className="text-xs text-white/30">₹{c.amount.toLocaleString('en-IN')}</p>
                  </div>
                  <span className="text-xs text-violet-400 font-semibold">+₹{(c.expected_return - c.amount).toLocaleString('en-IN')}</span>
                </div>
              ))}
            </div>
          </motion.div>
        </div>
      </div>
    </DashboardLayout>
  );
};

export default LoanDetails;
