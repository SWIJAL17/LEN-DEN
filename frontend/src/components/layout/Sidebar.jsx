import React, { useState } from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import { useAuth } from '../../context/AuthContext';
import { motion, AnimatePresence } from 'framer-motion';

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
    navigate('/login');
  };

  return (
    <motion.aside
      initial={{ x: -50, opacity: 0 }}
      animate={{ x: 0, opacity: 1, width: collapsed ? 80 : 280 }}
      transition={{ type: "spring", stiffness: 200, damping: 25 }}
      className="fixed left-0 top-0 h-screen bg-dark-900/60 backdrop-blur-3xl border-r border-white/10 
                   flex flex-col z-50 shadow-2xl"
    >
      {/* Decorative Glow */}
      <div className="absolute top-0 left-0 w-full h-32 bg-gradient-to-b from-emerald-500/10 to-transparent pointer-events-none" />

      {/* Logo */}
      <div className="p-6 flex items-center gap-4 relative z-10">
        <motion.div whileHover={{ scale: 1.05 }} className="w-12 h-12 rounded-xl bg-gradient-primary flex items-center justify-center text-2xl font-bold text-white shrink-0 shadow-glow-green">
          M
        </motion.div>
        <AnimatePresence>
          {!collapsed && (
            <motion.span initial={{ opacity: 0, x: -10 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: -10 }} className="font-display font-bold text-white text-xl tracking-wide whitespace-nowrap">
              MicroLend
            </motion.span>
          )}
        </AnimatePresence>
      </div>

      {/* Nav Items */}
      <nav className="flex-1 px-4 py-6 space-y-2 relative z-10 overflow-y-auto custom-scrollbar">
        {items.map((item) => (
          <NavLink
            key={item.path}
            to={item.path}
            className={({ isActive }) => `relative flex items-center gap-4 px-4 py-3.5 rounded-2xl transition-all duration-300 group ${isActive ? 'text-white' : 'text-white/50 hover:text-white'}`}
          >
            {({ isActive }) => (
              <>
                {isActive && (
                  <motion.div layoutId="activeNav" className="absolute inset-0 bg-gradient-to-r from-emerald-500/20 to-cyan-500/10 rounded-2xl border border-emerald-500/30 shadow-inner" initial={false} transition={{ type: "spring", stiffness: 300, damping: 30 }} />
                )}
                <motion.span whileHover={{ scale: 1.1 }} className={`text-xl relative z-10 ${isActive ? 'drop-shadow-glow' : 'grayscale group-hover:grayscale-0'}`}>
                  {item.icon}
                </motion.span>
                <AnimatePresence>
                  {!collapsed && (
                    <motion.span initial={{ opacity: 0, width: 0 }} animate={{ opacity: 1, width: "auto" }} exit={{ opacity: 0, width: 0 }} className="font-medium text-sm whitespace-nowrap relative z-10">
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
      <div className="p-5 border-t border-white/10 relative z-10 bg-dark-800/30">
        <div className={`flex items-center gap-4 mb-4 ${collapsed ? 'justify-center' : ''}`}>
          <div className="w-10 h-10 rounded-full bg-gradient-purple flex items-center justify-center text-sm font-bold text-white shrink-0 shadow-glow-purple border border-white/20">
            {user?.name?.[0]?.toUpperCase() || 'U'}
          </div>
          <AnimatePresence>
            {!collapsed && (
              <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="flex-1 min-w-0">
                <p className="text-sm font-bold text-white truncate">{user?.name}</p>
                <p className="text-xs text-emerald-400 font-medium capitalize">{user?.role}</p>
              </motion.div>
            )}
          </AnimatePresence>
        </div>
        <motion.button
          whileHover={{ scale: 1.02, backgroundColor: "rgba(244, 63, 94, 0.15)" }}
          whileTap={{ scale: 0.98 }}
          onClick={handleLogout}
          className={`w-full flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium text-white/50 border border-transparent hover:border-rose-500/30 hover:text-rose-400 transition-all ${collapsed ? 'justify-center' : ''}`}
        >
          <span className="text-lg">🚪</span>
          <AnimatePresence>
            {!collapsed && <motion.span initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="whitespace-nowrap">Sign Out</motion.span>}
          </AnimatePresence>
        </motion.button>
      </div>

      {/* Collapse Toggle */}
      <motion.button
        whileHover={{ scale: 1.1 }}
        whileTap={{ scale: 0.9 }}
        onClick={() => setCollapsed(!collapsed)}
        className="absolute -right-4 top-10 w-8 h-8 rounded-full bg-dark-700 border border-white/10 
                   flex items-center justify-center text-sm text-white/50 hover:text-white hover:border-white/30 shadow-lg z-50 backdrop-blur-md"
      >
        {collapsed ? '→' : '←'}
      </motion.button>
    </motion.aside>
  );
};

export default Sidebar;
