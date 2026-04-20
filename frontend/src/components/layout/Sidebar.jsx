import React, { useState } from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import { useAuth } from '../../context/AuthContext';
import { motion, AnimatePresence } from 'framer-motion';
import LendenLogo from '../LendenLogo';

const navItems = {
  borrower: [
    { path: '/dashboard', label: 'Dashboard', icon: '📊' },
    { path: '/marketplace', label: 'Marketplace', icon: '🏪' },
    { path: '/my-loans', label: 'My Loans', icon: '📋' },
    { path: '/create-loan', label: 'New Loan', icon: '➕' },
    { path: '/wallet', label: 'Wallet', icon: '💰' },
    { path: '/profile', label: 'Profile', icon: '👤' },
  ],
  lender: [
    { path: '/dashboard', label: 'Dashboard', icon: '📊' },
    { path: '/marketplace', label: 'Marketplace', icon: '🏪' },
    { path: '/my-loans', label: 'Investments', icon: '📈' },
    { path: '/wallet', label: 'Wallet', icon: '💰' },
    { path: '/profile', label: 'Profile', icon: '👤' },
  ],
  admin: [
    { path: '/dashboard', label: 'Dashboard', icon: '📊' },
    { path: '/admin', label: 'Admin Panel', icon: '⚙️' },
    { path: '/marketplace', label: 'Marketplace', icon: '🏪' },
    { path: '/wallet', label: 'Wallet', icon: '💰' },
    { path: '/profile', label: 'Profile', icon: '👤' },
  ],
};

const Sidebar = () => {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const [collapsed, setCollapsed] = useState(false);
  const items = navItems[user?.role] || navItems.borrower;

  const handleLogout = () => {
    logout();
    navigate('/');
  };

  return (
    <motion.aside
      initial={{ x: -50, opacity: 0 }}
      animate={{ x: 0, opacity: 1, width: collapsed ? 80 : 280 }}
      transition={{ type: "spring", stiffness: 200, damping: 25 }}
      className="fixed left-0 top-0 h-screen bg-dark-900/80 backdrop-blur-2xl border-r border-white/[0.06] flex flex-col z-50"
    >
      {/* Top Glow */}
      <div className="absolute top-0 left-0 w-full h-40 bg-gradient-to-b from-violet-500/[0.06] to-transparent pointer-events-none" />

      {/* Logo */}
      <div className="p-6 flex items-center gap-4 relative z-10">
        <motion.div whileHover={{ scale: 1.05 }} className="shrink-0">
          <LendenLogo size={44} />
        </motion.div>
        <AnimatePresence>
          {!collapsed && (
            <motion.span initial={{ opacity: 0, x: -10 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: -10 }}
              className="font-display font-bold text-white text-xl tracking-tight whitespace-nowrap">
              Len<span className="text-violet-400">den</span>
            </motion.span>
          )}
        </AnimatePresence>
      </div>

      {/* Nav Items */}
      <nav className="flex-1 px-3 py-4 space-y-1 relative z-10 overflow-y-auto no-scrollbar">
        {items.map((item) => (
          <NavLink
            key={item.path}
            to={item.path}
            className={({ isActive }) => `relative flex items-center gap-4 px-4 py-3 rounded-xl transition-all duration-200 group ${isActive ? 'text-white' : 'text-white/45 hover:text-white/80'}`}
          >
            {({ isActive }) => (
              <>
                {isActive && (
                  <motion.div layoutId="activeNav" className="absolute inset-0 bg-violet-500/10 rounded-xl border border-violet-500/20"
                    initial={false} transition={{ type: "spring", stiffness: 300, damping: 30 }} />
                )}
                <motion.span whileHover={{ scale: 1.1 }} className={`text-lg relative z-10 transition-all ${isActive ? '' : 'grayscale-[0.5] group-hover:grayscale-0'}`}>
                  {item.icon}
                </motion.span>
                <AnimatePresence>
                  {!collapsed && (
                    <motion.span initial={{ opacity: 0, width: 0 }} animate={{ opacity: 1, width: "auto" }} exit={{ opacity: 0, width: 0 }}
                      className="font-medium text-sm whitespace-nowrap relative z-10">
                      {item.label}
                    </motion.span>
                  )}
                </AnimatePresence>
              </>
            )}
          </NavLink>
        ))}
      </nav>

      {/* User Section */}
      <div className="p-4 border-t border-white/[0.06] relative z-10">
        <div className={`flex items-center gap-3 mb-3 ${collapsed ? 'justify-center' : ''}`}>
          <div className="w-9 h-9 rounded-full bg-gradient-primary flex items-center justify-center text-sm font-bold text-white shrink-0">
            {user?.name?.[0]?.toUpperCase() || 'U'}
          </div>
          <AnimatePresence>
            {!collapsed && (
              <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="flex-1 min-w-0">
                <p className="text-sm font-semibold text-white truncate">{user?.name}</p>
                <p className="text-xs text-violet-400 capitalize">{user?.role}</p>
              </motion.div>
            )}
          </AnimatePresence>
        </div>
        <motion.button
          whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.98 }}
          onClick={handleLogout}
          className={`w-full flex items-center gap-3 px-4 py-2.5 rounded-xl text-sm text-white/40 hover:text-rose-400 hover:bg-rose-500/10 transition-all ${collapsed ? 'justify-center' : ''}`}
        >
          <span className="text-base">🚪</span>
          <AnimatePresence>
            {!collapsed && <motion.span initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="whitespace-nowrap">Sign Out</motion.span>}
          </AnimatePresence>
        </motion.button>
      </div>

      {/* Collapse Toggle */}
      <motion.button
        whileHover={{ scale: 1.15 }} whileTap={{ scale: 0.9 }}
        onClick={() => setCollapsed(!collapsed)}
        className="absolute -right-3.5 top-10 w-7 h-7 rounded-full bg-dark-700 border border-white/10 
                   flex items-center justify-center text-xs text-white/40 hover:text-white hover:border-violet-500/30 shadow-lg z-50"
      >
        {collapsed ? '›' : '‹'}
      </motion.button>
    </motion.aside>
  );
};

export default Sidebar;
