import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import DashboardLayout from '../components/layout/DashboardLayout';
import { useAuth } from '../context/AuthContext';
import { walletAPI } from '../services/api';
import toast from 'react-hot-toast';

const demoTransactions = [
  { id: 1, type: 'deposit', amount: 10000, balance_after: 15000, description: 'Wallet deposit', created_at: '2026-04-15T10:30:00' },
  { id: 2, type: 'loan_funding', amount: 3000, balance_after: 12000, description: 'Funded: Small Business Expansion', created_at: '2026-04-14T14:20:00' },
  { id: 3, type: 'repayment_in', amount: 1250, balance_after: 13250, description: 'Repayment from Priya Sharma', created_at: '2026-04-13T09:00:00' },
  { id: 4, type: 'withdrawal', amount: 2000, balance_after: 11250, description: 'Wallet withdrawal', created_at: '2026-04-12T16:45:00' },
  { id: 5, type: 'loan_funding', amount: 5000, balance_after: 6250, description: 'Funded: Education Loan - MBA', created_at: '2026-04-10T11:15:00' },
  { id: 6, type: 'deposit', amount: 20000, balance_after: 26250, description: 'Wallet deposit', created_at: '2026-04-08T08:00:00' },
  { id: 7, type: 'repayment_in', amount: 2100, balance_after: 28350, description: 'Repayment from Rahul Verma', created_at: '2026-04-05T12:30:00' },
];

const typeConfig = {
  deposit: { icon: '💰', label: 'Deposit', color: 'text-emerald-400', sign: '+' },
  withdrawal: { icon: '📤', label: 'Withdrawal', color: 'text-rose-400', sign: '-' },
  loan_funding: { icon: '🏦', label: 'Investment', color: 'text-cyan-400', sign: '-' },
  loan_disbursement: { icon: '📥', label: 'Loan Received', color: 'text-emerald-400', sign: '+' },
  repayment_out: { icon: '📤', label: 'Repayment', color: 'text-rose-400', sign: '-' },
  repayment_in: { icon: '📥', label: 'Return', color: 'text-emerald-400', sign: '+' },
  penalty: { icon: '⚠️', label: 'Penalty', color: 'text-amber-400', sign: '-' },
};

const Wallet = () => {
  const { user, updateUser } = useAuth();
  const [tab, setTab] = useState('all');
  const [amount, setAmount] = useState('');
  const [showAction, setShowAction] = useState(null);
  const [transactions, setTransactions] = useState(demoTransactions);
  const [balance, setBalance] = useState(parseFloat(user?.walletBalance || 15000));

  // Fetch real wallet data from backend
  useEffect(() => {
    const fetchWallet = async () => {
      try {
        const res = await walletAPI.get();
        setBalance(parseFloat(res.data.balance));
        if (res.data.transactions?.length > 0) setTransactions(res.data.transactions);
        updateUser({ walletBalance: res.data.balance });
      } catch {
        // Use demo data
      }
    };
    fetchWallet();
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  const handleAction = async (action) => {
    const amt = parseFloat(amount);
    if (!amt || amt <= 0) return toast.error('Enter a valid amount');
    if (action === 'withdraw' && amt > balance) return toast.error('Insufficient balance');
    
    try {
      const res = action === 'deposit' 
        ? await walletAPI.deposit(amt) 
        : await walletAPI.withdraw(amt);
      setBalance(parseFloat(res.data.balance));
      updateUser({ walletBalance: res.data.balance });
      toast.success(res.data.message);
      // Refresh transactions
      const walletRes = await walletAPI.get();
      if (walletRes.data.transactions?.length > 0) setTransactions(walletRes.data.transactions);
    } catch (err) {
      // Fallback demo
      const newBal = action === 'deposit' ? balance + amt : balance - amt;
      setBalance(newBal);
      updateUser({ walletBalance: newBal });
      toast.success(`${action === 'deposit' ? 'Deposited' : 'Withdrawn'} ₹${amt.toLocaleString('en-IN')} (Demo)`);
    }
    setShowAction(null);
    setAmount('');
  };

  const filtered = tab === 'all' ? transactions : transactions.filter(t => {
    if (tab === 'in') return ['deposit', 'repayment_in', 'loan_disbursement'].includes(t.type);
    return ['withdrawal', 'loan_funding', 'repayment_out', 'penalty'].includes(t.type);
  });

  return (
    <DashboardLayout title="Wallet">
      {/* Balance Card */}
      <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} className="glass-card p-8 mb-8 relative overflow-hidden">
        <div className="absolute top-0 right-0 w-64 h-64 bg-emerald-500/5 rounded-full blur-3xl -translate-y-1/2 translate-x-1/2" />
        <p className="text-sm text-white/40 mb-2">Available Balance</p>
        <h2 className="font-display text-5xl font-bold text-white mb-6">
          ₹{balance.toLocaleString('en-IN', { minimumFractionDigits: 2 })}
        </h2>
        <div className="flex flex-col gap-3">
          <motion.button whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.98 }} onClick={() => setShowAction('deposit')} className="btn-gradient w-full !py-4">
            Deposit Funds
          </motion.button>
          <motion.button whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.98 }} onClick={() => setShowAction('withdraw')} className="w-full py-4 rounded-xl font-semibold text-rose-400 bg-rose-500/10 border border-rose-500/20 hover:bg-rose-500/20 transition-all">
            Withdraw Funds
          </motion.button>
        </div>
      </motion.div>

      {/* Deposit/Withdraw Modal */}
      {showAction && (
        <motion.div initial={{ opacity: 0, y: -10 }} animate={{ opacity: 1, y: 0 }} className="glass-card p-6 mb-8 max-w-md">
          <h3 className="font-display font-semibold text-white mb-4 capitalize">{showAction} Funds</h3>
          <input type="number" value={amount} onChange={e => setAmount(e.target.value)}
            placeholder="Enter amount" className="input-dark mb-4" />
          <div className="flex gap-3">
            <button onClick={() => handleAction(showAction)}
              className={showAction === 'deposit' ? 'btn-gradient flex-1' : 'btn-gradient-purple flex-1'}>
              Confirm {showAction}
            </button>
            <button onClick={() => { setShowAction(null); setAmount(''); }} className="btn-outline">Cancel</button>
          </div>
        </motion.div>
      )}

      {/* Transaction History */}
      <div className="glass-card p-6">
        <div className="flex items-center justify-between mb-6">
          <h3 className="font-display font-semibold text-white">Transaction History</h3>
          <div className="flex items-center gap-1 p-1 rounded-lg bg-dark-800/50">
            {['all', 'in', 'out'].map(t => (
              <button key={t} onClick={() => setTab(t)}
                className={`px-3 py-1.5 rounded-md text-xs font-medium transition-all capitalize
                  ${tab === t ? 'bg-white/10 text-white' : 'text-white/30 hover:text-white/50'}`}>
                {t === 'in' ? 'Credits' : t === 'out' ? 'Debits' : 'All'}
              </button>
            ))}
          </div>
        </div>

        <div className="space-y-2">
          {filtered.map((tx, i) => {
            const config = typeConfig[tx.type] || typeConfig.deposit;
            const isCredit = config.sign === '+';
            return (
              <motion.div key={tx.id} initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: i * 0.05 }}
                className="flex items-center gap-4 p-4 rounded-xl hover:bg-white/[0.02] transition-colors">
                <div className="w-10 h-10 rounded-xl bg-dark-600 flex items-center justify-center text-lg">{config.icon}</div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm text-white font-medium">{tx.description}</p>
                  <p className="text-xs text-white/30">{new Date(tx.created_at).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })}</p>
                </div>
                <div className="text-right">
                  <p className={`text-sm font-semibold ${isCredit ? 'text-emerald-400' : 'text-rose-400'}`}>
                    {config.sign}₹{tx.amount.toLocaleString('en-IN')}
                  </p>
                  <p className="text-xs text-white/20">Bal: ₹{tx.balance_after.toLocaleString('en-IN')}</p>
                </div>
              </motion.div>
            );
          })}
        </div>
      </div>
    </DashboardLayout>
  );
};

export default Wallet;
