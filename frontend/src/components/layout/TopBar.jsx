import React from 'react';
import { useAuth } from '../../context/AuthContext';

const TopBar = ({ title }) => {
  const { user } = useAuth();

  return (
    <header className="h-16 flex items-center justify-between px-8 border-b border-white/5 bg-dark-800/40 backdrop-blur-md sticky top-0 z-40">
      <h1 className="font-display font-bold text-xl text-white">{title}</h1>
      <div className="flex items-center gap-4">
        {/* Wallet Balance Pill */}
        <div className="flex items-center gap-2 px-4 py-2 rounded-full bg-dark-700/60 border border-white/5">
          <span className="text-emerald-400 text-sm">💰</span>
          <span className="text-sm font-semibold text-white">
            ₹{parseFloat(user?.walletBalance || 0).toLocaleString('en-IN', { minimumFractionDigits: 2 })}
          </span>
        </div>
        {/* Avatar */}
        <div className="w-9 h-9 rounded-full bg-gradient-primary flex items-center justify-center text-sm font-bold text-white">
          {user?.name?.[0]?.toUpperCase() || 'U'}
        </div>
      </div>
    </header>
  );
};

export default TopBar;
