import React, { useEffect } from 'react';
import { motion } from 'framer-motion';
import DashboardLayout from '../components/layout/DashboardLayout';
import { useAuth } from '../context/AuthContext';
import { userAPI } from '../services/api';
import toast from 'react-hot-toast';

const Profile = () => {
  const { user, updateUser } = useAuth();

  useEffect(() => {
    const fetchProfile = async () => {
      try {
        const res = await userAPI.getProfile();
        if (res.data.user) updateUser(res.data.user);
      } catch {
        // Use existing context data
      }
    };
    fetchProfile();
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  return (
    <DashboardLayout title="Profile">
      <div className="max-w-3xl mx-auto space-y-6">
        {/* Profile Header */}
        <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} className="glass-card p-8 relative overflow-hidden">
          <div className="absolute top-0 right-0 w-40 h-40 bg-violet-500/10 rounded-full blur-3xl" />
          <div className="flex items-center gap-6 relative">
            <div className="w-20 h-20 rounded-2xl bg-gradient-primary flex items-center justify-center text-3xl font-bold text-white shadow-glow-purple">
              {user?.name?.[0]?.toUpperCase() || 'U'}
            </div>
            <div>
              <h2 className="font-display text-2xl font-bold text-white">{user?.name}</h2>
              <p className="text-white/40">{user?.email}</p>
              <span className="badge badge-info mt-2 capitalize">{user?.role}</span>
            </div>
          </div>
        </motion.div>

        {/* Account Info */}
        <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.1 }} className="glass-card p-6">
          <h3 className="font-display font-semibold text-white mb-6">Account Information</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {[
              { label: 'Full Name', value: user?.name },
              { label: 'Email', value: user?.email },
              { label: 'Role', value: user?.role, capitalize: true },
              { label: 'Wallet Balance', value: `₹${parseFloat(user?.walletBalance || 0).toLocaleString('en-IN')}` },
              { label: 'Credit Score', value: '720 / 900' },
              { label: 'KYC Status', value: 'Verified ✅' },
              { label: 'Member Since', value: 'March 2026' },
              { label: 'Account Status', value: 'Active' },
            ].map((item, i) => (
              <div key={i}>
                <label className="block text-xs text-white/30 mb-1.5">{item.label}</label>
                <p className={`text-white font-medium ${item.capitalize ? 'capitalize' : ''}`}>{item.value || '—'}</p>
              </div>
            ))}
          </div>
        </motion.div>

        {/* Security */}
        <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.2 }} className="glass-card p-6">
          <h3 className="font-display font-semibold text-white mb-4">Security</h3>
          <div className="space-y-3">
            <div className="flex items-center justify-between p-4 rounded-xl bg-dark-800/50">
              <div><p className="text-sm text-white">Password</p><p className="text-xs text-white/30">Last changed 30 days ago</p></div>
              <motion.button whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }} onClick={() => toast('Password reset link sent to email! 📧', { icon: '🔒' })} className="btn-outline !py-2 !px-4 text-xs">Change</motion.button>
            </div>
            <div className="flex items-center justify-between p-4 rounded-xl bg-dark-800/50">
              <div><p className="text-sm text-white">Two-Factor Auth</p><p className="text-xs text-white/30">Not enabled</p></div>
              <motion.button whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }} onClick={() => toast.success('2FA Setup Instructions sent to your email.')} className="btn-outline !py-2 !px-4 text-xs">Enable</motion.button>
            </div>
          </div>
        </motion.div>
      </div>
    </DashboardLayout>
  );
};

export default Profile;
