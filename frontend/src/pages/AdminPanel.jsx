import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import DashboardLayout from '../components/layout/DashboardLayout';
import StatCard from '../components/ui/StatCard';
import { adminAPI } from '../services/api';
import toast from 'react-hot-toast';

const demoPendingLoans = [
  { id: 'p1', title: 'Grocery Store Expansion', borrower_name: 'Suresh Kumar', borrower_email: 'suresh@email.com', amount: 35000, interest_rate: 14, tenure_months: 18, risk_score: 'medium', credit_score: 680, created_at: '2026-04-16' },
  { id: 'p2', title: 'Freelance Equipment', borrower_name: 'Kavya Nair', borrower_email: 'kavya@email.com', amount: 12000, interest_rate: 10, tenure_months: 6, risk_score: 'low', credit_score: 750, created_at: '2026-04-15' },
];

const demoUsers = [
  { id: 'u1', name: 'Priya Sharma', email: 'priya@email.com', role: 'borrower', wallet_balance: 5200, credit_score: 720, is_active: true },
  { id: 'u2', name: 'Sam Lender', email: 'sam@email.com', role: 'lender', wallet_balance: 48000, credit_score: 800, is_active: true },
];

const AdminPanel = () => {
  const [tab, setTab] = useState('approvals');
  const [loans, setLoans] = useState(demoPendingLoans);
  const [users, setUsers] = useState(demoUsers);
  const [showAddUser, setShowAddUser] = useState(false);
  const [newUser, setNewUser] = useState({ name: '', email: '', password: '', role: 'borrower' });
  const [loading, setLoading] = useState(false);

  // Fetch real data from backend
  useEffect(() => {
    const fetchData = async () => {
      try {
        const pendingRes = await adminAPI.getPending();
        if (pendingRes.data.loans?.length >= 0) setLoans(pendingRes.data.loans);
        const usersRes = await adminAPI.getUsers();
        if (usersRes.data.users?.length > 0) setUsers(usersRes.data.users);
      } catch {
        // Use demo data
      }
    };
    fetchData();
  }, []);

  const handleApprove = async (id) => {
    try {
      await adminAPI.approve(id);
    } catch {
      // Demo mode
    }
    setLoans(loans.filter(l => l.id !== id));
    toast.success('Loan approved and listed on marketplace!');
  };

  const handleReject = async (id) => {
    try {
      await adminAPI.reject(id, 'Does not meet platform criteria');
    } catch {
      // Demo mode
    }
    setLoans(loans.filter(l => l.id !== id));
    toast.error('Loan rejected');
  };

  const handleCreateUser = async (e) => {
    e.preventDefault();
    setLoading(true);
    try {
      const res = await adminAPI.createUser(newUser);
      setUsers([res.data.user, ...users]);
      toast.success('User created successfully!');
      setShowAddUser(false);
      setNewUser({ name: '', email: '', password: '', role: 'borrower' });
    } catch (err) {
      toast.error(err.response?.data?.error || 'Failed to create user');
    } finally {
      setLoading(false);
    }
  };

  const riskBadge = { low: 'badge-low', medium: 'badge-medium', high: 'badge-high' };

  return (
    <DashboardLayout title="Admin Panel">
      {/* Stats */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5 mb-8">
        <StatCard icon="👥" label="Total Users" value={users.length.toString()} color="emerald" trend={22} delay={0} />
        <StatCard icon="📋" label="Active Loans" value="89" color="cyan" trend={5} delay={1} />
        <StatCard icon="💰" label="Platform Volume" value="₹45L" color="purple" trend={18} delay={2} />
        <StatCard icon="⏳" label="Pending" value={loans.length.toString()} color="amber" delay={3} />
      </div>

      {/* Tabs */}
      <div className="flex justify-between items-center mb-8">
        <div className="flex gap-1 p-1 rounded-xl bg-dark-700/50 border border-white/5 w-fit">
          {['approvals', 'users'].map(t => (
            <button key={t} onClick={() => setTab(t)}
              className={`px-5 py-2.5 rounded-lg text-sm font-medium transition-all capitalize
                ${tab === t ? 'bg-gradient-primary text-white' : 'text-white/40 hover:text-white'}`}>
              {t === 'approvals' ? `Loan Approvals (${loans.length})` : `Users (${users.length})`}
            </button>
          ))}
        </div>
        {tab === 'users' && (
          <motion.button whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.98 }} onClick={() => setShowAddUser(true)} className="btn-gradient !py-2.5 !px-5 text-sm flex items-center gap-2">
            <span>➕</span> Add New User
          </motion.button>
        )}
      </div>

      {/* Approvals Tab */}
      {tab === 'approvals' && (
        <div className="space-y-4">
          {loans.map((loan, i) => (
            <motion.div key={loan.id} initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.05 }}
              className="glass-card p-6">
              <div className="flex flex-col lg:flex-row lg:items-center gap-6">
                <div className="flex-1">
                  <div className="flex items-center gap-3 mb-2">
                    <h3 className="font-semibold text-white">{loan.title}</h3>
                    <span className={`badge ${riskBadge[loan.risk_score]} uppercase text-xs`}>{loan.risk_score}</span>
                  </div>
                  <p className="text-sm text-white/40 mb-3">by {loan.borrower_name} · {loan.borrower_email}</p>
                  <div className="flex flex-wrap gap-4 text-sm">
                    <span className="text-white/60">Amount: <span className="text-white font-semibold">₹{loan.amount?.toLocaleString('en-IN')}</span></span>
                    <span className="text-white/60">Rate: <span className="text-cyan-400 font-semibold">{loan.interest_rate}%</span></span>
                    <span className="text-white/60">Tenure: <span className="text-white">{loan.tenure_months}mo</span></span>
                    <span className="text-white/60">Credit: <span className={`font-semibold ${loan.credit_score >= 700 ? 'text-emerald-400' : loan.credit_score >= 600 ? 'text-amber-400' : 'text-rose-400'}`}>{loan.credit_score}</span></span>
                  </div>
                </div>
                <div className="flex gap-2 shrink-0">
                  <motion.button whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }} onClick={() => handleApprove(loan.id)} className="btn-gradient !py-2.5 !px-5 text-sm">✅ Approve</motion.button>
                  <motion.button whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }} onClick={() => handleReject(loan.id)} className="px-5 py-2.5 rounded-xl text-sm font-semibold text-rose-400 bg-rose-500/10 border border-rose-500/20 hover:bg-rose-500/20 transition-all">❌ Reject</motion.button>
                </div>
              </div>
            </motion.div>
          ))}
          {loans.length === 0 && (
            <div className="text-center py-16"><p className="text-4xl mb-3">✅</p><p className="text-white/40">All caught up! No pending approvals.</p></div>
          )}
        </div>
      )}

      {/* Users Tab */}
      {tab === 'users' && (
        <div className="glass-card overflow-hidden">
          <table className="w-full text-sm">
            <thead>
              <tr className="text-white/30 border-b border-white/5">
                <th className="text-left py-4 px-6">User</th>
                <th className="text-left py-4 px-4">Role</th>
                <th className="text-right py-4 px-4">Balance</th>
                <th className="text-center py-4 px-4">Credit</th>
                <th className="text-center py-4 px-4">Status</th>
              </tr>
            </thead>
            <tbody>
              {users.map((u, i) => (
                <motion.tr key={u.id} initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: i * 0.05 }}
                  className="border-b border-white/5 hover:bg-white/[0.02]">
                  <td className="py-4 px-6">
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 rounded-full bg-gradient-primary flex items-center justify-center text-xs font-bold text-white">{u.name[0]}</div>
                      <div><p className="text-white font-medium">{u.name}</p><p className="text-xs text-white/30">{u.email}</p></div>
                    </div>
                  </td>
                  <td className="py-4 px-4"><span className="badge badge-info capitalize">{u.role}</span></td>
                  <td className="py-4 px-4 text-right text-white">₹{(u.wallet_balance || 0).toLocaleString('en-IN')}</td>
                  <td className="py-4 px-4 text-center text-white">{u.credit_score || 700}</td>
                  <td className="py-4 px-4 text-center">
                    <span className={`badge ${u.is_active ? 'badge-low' : 'badge-high'}`}>{u.is_active ? 'Active' : 'Inactive'}</span>
                  </td>
                </motion.tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Add User Modal */}
      <AnimatePresence>
        {showAddUser && (
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-dark-900/80 backdrop-blur-sm">
            <motion.div initial={{ scale: 0.9, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} exit={{ scale: 0.9, opacity: 0 }} className="glass-card p-6 w-full max-w-md relative">
              <button onClick={() => setShowAddUser(false)} className="absolute top-4 right-4 text-white/50 hover:text-white">✕</button>
              <h2 className="text-xl font-bold text-white mb-6">Add New User</h2>
              <form onSubmit={handleCreateUser} className="space-y-4">
                <div>
                  <label className="block text-xs text-white/50 mb-1">Full Name</label>
                  <input required type="text" value={newUser.name} onChange={e => setNewUser({ ...newUser, name: e.target.value })} className="input-dark w-full" placeholder="John Doe" />
                </div>
                <div>
                  <label className="block text-xs text-white/50 mb-1">Email</label>
                  <input required type="email" value={newUser.email} onChange={e => setNewUser({ ...newUser, email: e.target.value })} className="input-dark w-full" placeholder="john@example.com" />
                </div>
                <div>
                  <label className="block text-xs text-white/50 mb-1">Role</label>
                  <select value={newUser.role} onChange={e => setNewUser({ ...newUser, role: e.target.value })} className="input-dark w-full appearance-none">
                    <option value="borrower">Borrower</option>
                    <option value="lender">Lender</option>
                  </select>
                </div>
                <div>
                  <label className="block text-xs text-white/50 mb-1">Temporary Password</label>
                  <input required type="password" value={newUser.password} onChange={e => setNewUser({ ...newUser, password: e.target.value })} className="input-dark w-full" placeholder="••••••••" />
                </div>
                <button type="submit" disabled={loading} className="btn-gradient w-full mt-4">
                  {loading ? 'Creating...' : 'Create User'}
                </button>
              </form>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </DashboardLayout>
  );
};

export default AdminPanel;
