import React from 'react';
import { useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { useAuth } from '../context/AuthContext';
import { authAPI } from '../services/api';
import toast, { Toaster } from 'react-hot-toast';

const roles = [
  {
    id: 'borrower',
    icon: '🏦',
    title: 'Borrower',
    description: 'Request loans and get funded by multiple lenders at competitive rates',
    features: ['Request micro-loans', 'Track repayments', 'Build credit score'],
    gradient: 'from-emerald-500 to-cyan-500',
    glow: 'shadow-glow-green',
  },
  {
    id: 'lender',
    icon: '💎',
    title: 'Lender',
    description: 'Invest in vetted loans and earn attractive returns on your capital',
    features: ['Fund loans fractionally', 'Earn interest income', 'Portfolio analytics'],
    gradient: 'from-purple-500 to-pink-500',
    glow: 'shadow-glow-purple',
  },
];

const Role = () => {
  const { login, updateUser } = useAuth();
  const navigate = useNavigate();

  const selectRole = async (role) => {
    try {
      // Try to update role via backend API
      const res = await authAPI.setRole(role);
      login(res.data.user, res.data.token);
      toast.success(`Welcome as ${role}!`);
    } catch {
      // Fallback to local update if backend not available
      updateUser({ role });
      toast.success(`Welcome as ${role}! (Demo mode)`);
    }
    navigate('/dashboard');
  };

  return (
    <div className="min-h-screen flex items-center justify-center relative overflow-hidden">
      <Toaster position="top-right" toastOptions={{ style: { background: '#1e2030', color: '#e0e0e8', border: '1px solid rgba(255,255,255,0.05)', borderRadius: '12px' } }} />
      <div className="absolute inset-0">
        <div className="absolute top-1/3 left-1/3 w-80 h-80 bg-emerald-500/10 rounded-full blur-3xl animate-pulse-slow" />
        <div className="absolute bottom-1/3 right-1/3 w-80 h-80 bg-purple-500/10 rounded-full blur-3xl animate-pulse-slow" style={{ animationDelay: '2s' }} />
      </div>

      <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} className="relative z-10 w-full max-w-2xl px-6">
        <div className="text-center mb-10">
          <h1 className="font-display text-4xl font-bold text-white mb-3">Choose Your Path</h1>
          <p className="text-white/40 text-lg">How would you like to use MicroLend?</p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {roles.map((role, i) => (
            <motion.div
              key={role.id}
              initial={{ opacity: 0, y: 30 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: i * 0.15, duration: 0.5 }}
              whileHover={{ y: -5, transition: { duration: 0.2 } }}
              onClick={() => selectRole(role.id)}
              className="glass-card p-8 cursor-pointer group transition-all duration-300 hover:border-white/10"
            >
              <div className={`w-16 h-16 rounded-2xl bg-gradient-to-br ${role.gradient} flex items-center justify-center text-3xl mb-6 ${role.glow} group-hover:scale-110 transition-transform`}>
                {role.icon}
              </div>
              <h2 className="font-display text-2xl font-bold text-white mb-2">{role.title}</h2>
              <p className="text-sm text-white/40 mb-6">{role.description}</p>
              <ul className="space-y-2">
                {role.features.map((f, j) => (
                  <li key={j} className="flex items-center gap-2 text-sm text-white/60">
                    <span className="text-emerald-400">✓</span> {f}
                  </li>
                ))}
              </ul>
              <div className={`mt-6 py-3 rounded-xl bg-gradient-to-r ${role.gradient} text-center text-sm font-semibold text-white opacity-0 group-hover:opacity-100 transition-opacity`}>
                Continue as {role.title}
              </div>
            </motion.div>
          ))}
        </div>
      </motion.div>
    </div>
  );
};

export default Role;