import React from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../../context/AuthContext';
import { motion } from 'framer-motion';

const TopBar = ({ title }) => {
  const { user } = useAuth();
  const navigate = useNavigate();

  return (
    <header className="h-16 flex items-center justify-between px-8 border-b border-white/[0.04] bg-dark-900/60 backdrop-blur-xl sticky top-0 z-40">
      <h1 className="font-display font-bold text-xl text-white">{title}</h1>
      <div className="flex items-center gap-3">
        {/* Notifications */}
        <motion.button whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }}
          className="w-9 h-9 rounded-xl bg-white/[0.04] border border-white/[0.06] flex items-center justify-center text-sm text-white/50 hover:text-white hover:border-white/10 transition-all relative">
          🔔
          <span className="absolute -top-1 -right-1 w-4 h-4 rounded-full bg-violet-500 text-[9px] font-bold text-white flex items-center justify-center">3</span>
        </motion.button>

        {/* Wallet Balance Pill */}
        <Link to="/wallet"
          className="flex items-center gap-2 px-4 py-2 rounded-xl bg-white/[0.04] border border-white/[0.06] hover:border-violet-500/20 transition-all">
          <span className="text-violet-400 text-sm">💰</span>
          <span className="text-sm font-semibold text-white">
            ₹{parseFloat(user?.walletBalance || 0).toLocaleString('en-IN', { minimumFractionDigits: 2 })}
          </span>
        </Link>

        {/* Avatar */}
        <motion.div whileHover={{ scale: 1.05 }} onClick={() => navigate('/profile')}
          className="w-9 h-9 rounded-full bg-gradient-primary flex items-center justify-center text-sm font-bold text-white cursor-pointer shadow-glow-purple">
          {user?.name?.[0]?.toUpperCase() || 'U'}
        </motion.div>
      </div>
    </header>
  );
};

export default TopBar;
