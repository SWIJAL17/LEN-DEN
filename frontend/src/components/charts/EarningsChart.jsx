import React from 'react';
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';

const generateDemoData = () => {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return months.map((month, i) => ({
    month,
    earnings: Math.floor(800 + Math.random() * 2000 + i * 200),
    investments: Math.floor(1500 + Math.random() * 3000 + i * 300),
  }));
};

const CustomTooltip = ({ active, payload, label }) => {
  if (!active || !payload) return null;
  return (
    <div className="glass-card p-3 text-xs border border-white/[0.08]">
      <p className="font-semibold text-white mb-1">{label}</p>
      {payload.map((entry, i) => (
        <p key={i} style={{ color: entry.color }} className="flex justify-between gap-4">
          <span className="text-white/40">{entry.name}:</span>
          <span className="font-semibold">₹{entry.value.toLocaleString('en-IN')}</span>
        </p>
      ))}
    </div>
  );
};

const EarningsChart = ({ data }) => {
  const chartData = data || generateDemoData();

  return (
    <div className="glass-card p-6">
      <div className="flex items-center justify-between mb-6">
        <h3 className="font-display font-semibold text-white">Earnings Overview</h3>
        <div className="flex items-center gap-4">
          <div className="flex items-center gap-1.5">
            <div className="w-2.5 h-2.5 rounded-full bg-violet-400" />
            <span className="text-xs text-white/35">Earnings</span>
          </div>
          <div className="flex items-center gap-1.5">
            <div className="w-2.5 h-2.5 rounded-full bg-blue-400" />
            <span className="text-xs text-white/35">Investments</span>
          </div>
        </div>
      </div>
      <ResponsiveContainer width="100%" height={280}>
        <AreaChart data={chartData} margin={{ top: 5, right: 5, left: -20, bottom: 0 }}>
          <defs>
            <linearGradient id="gradientEarnings" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#8b5cf6" stopOpacity={0.25} />
              <stop offset="100%" stopColor="#8b5cf6" stopOpacity={0} />
            </linearGradient>
            <linearGradient id="gradientInvestments" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#3b82f6" stopOpacity={0.2} />
              <stop offset="100%" stopColor="#3b82f6" stopOpacity={0} />
            </linearGradient>
          </defs>
          <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.03)" />
          <XAxis dataKey="month" stroke="rgba(255,255,255,0.15)" fontSize={11} />
          <YAxis stroke="rgba(255,255,255,0.15)" fontSize={11} />
          <Tooltip content={<CustomTooltip />} />
          <Area type="monotone" dataKey="earnings" name="Earnings" stroke="#8b5cf6" strokeWidth={2} fill="url(#gradientEarnings)" />
          <Area type="monotone" dataKey="investments" name="Investments" stroke="#3b82f6" strokeWidth={2} fill="url(#gradientInvestments)" />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
};

export default EarningsChart;
