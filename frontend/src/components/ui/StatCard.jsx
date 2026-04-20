import React from 'react';
import { motion } from 'framer-motion';

const StatCard = ({ icon, label, value, trend, color = 'violet', delay = 0 }) => {
  const colorMap = {
    violet: 'from-violet-500/15 to-violet-500/5 text-violet-400 border-violet-500/10',
    blue: 'from-blue-500/15 to-blue-500/5 text-blue-400 border-blue-500/10',
    emerald: 'from-emerald-500/15 to-emerald-500/5 text-emerald-400 border-emerald-500/10',
    cyan: 'from-cyan-500/15 to-cyan-500/5 text-cyan-400 border-cyan-500/10',
    purple: 'from-purple-500/15 to-purple-500/5 text-purple-400 border-purple-500/10',
    amber: 'from-amber-500/15 to-amber-500/5 text-amber-400 border-amber-500/10',
    rose: 'from-rose-500/15 to-rose-500/5 text-rose-400 border-rose-500/10',
  };

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: delay * 0.1, duration: 0.4 }}
      whileHover={{ y: -3, transition: { duration: 0.2 } }}
      className="glass-card p-6 cursor-default"
    >
      <div className="flex items-start justify-between mb-4">
        <div className={`w-11 h-11 rounded-xl bg-gradient-to-br ${colorMap[color]} 
                         flex items-center justify-center text-lg border`}>
          {icon}
        </div>
        {trend && (
          <span className={`text-xs font-semibold px-2 py-1 rounded-lg 
                           ${trend > 0 ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/15' : 'bg-rose-500/10 text-rose-400 border border-rose-500/15'}`}>
            {trend > 0 ? '↑' : '↓'} {Math.abs(trend)}%
          </span>
        )}
      </div>
      <p className="text-2xl font-bold text-white mb-1 font-display">{value}</p>
      <p className="text-sm text-white/35">{label}</p>
    </motion.div>
  );
};

export default StatCard;
