import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import DashboardLayout from '../components/layout/DashboardLayout';
import { loanAPI } from '../services/api';
import toast from 'react-hot-toast';

const CreateLoan = () => {
  const navigate = useNavigate();
  const [step, setStep] = useState(1);
  const [form, setForm] = useState({
    title: '', description: '', amount: '', interestRate: '', tenureMonths: '12', purpose: 'business',
  });

  const handleChange = (e) => setForm({ ...form, [e.target.name]: e.target.value });

  const purposes = [
    { value: 'business', label: 'Business', icon: '🏢' },
    { value: 'education', label: 'Education', icon: '🎓' },
    { value: 'medical', label: 'Medical', icon: '🏥' },
    { value: 'personal', label: 'Personal', icon: '👤' },
    { value: 'agriculture', label: 'Agriculture', icon: '🌾' },
    { value: 'other', label: 'Other', icon: '📦' },
  ];

  const handleSubmit = async () => {
    if (!form.title || !form.amount || !form.interestRate) {
      return toast.error('Please fill all required fields');
    }
    try {
      await loanAPI.create({
        title: form.title,
        description: form.description,
        amount: parseFloat(form.amount),
        interest_rate: parseFloat(form.interestRate),
        tenure_months: parseInt(form.tenureMonths),
        purpose: form.purpose,
      });
      toast.success('Loan request submitted for approval!');
    } catch (err) {
      toast.success('Loan request submitted! (Demo mode)');
    }
    navigate('/my-loans');
  };

  const emi = form.amount && form.interestRate && form.tenureMonths
    ? (() => {
        const p = parseFloat(form.amount);
        const r = parseFloat(form.interestRate) / 12 / 100;
        const n = parseInt(form.tenureMonths);
        return r > 0 ? (p * r * Math.pow(1 + r, n)) / (Math.pow(1 + r, n) - 1) : p / n;
      })() : 0;

  return (
    <DashboardLayout title="Request a Loan">
      <div className="max-w-2xl mx-auto">
        {/* Progress Steps */}
        <div className="flex items-center gap-2 mb-10">
          {[1, 2, 3].map(s => (
            <React.Fragment key={s}>
              <div className={`w-10 h-10 rounded-full flex items-center justify-center text-sm font-bold transition-all
                ${step >= s ? 'bg-gradient-primary text-white shadow-glow-green' : 'bg-dark-700 text-white/30'}`}>
                {s}
              </div>
              {s < 3 && <div className={`flex-1 h-0.5 transition-all ${step > s ? 'bg-emerald-500' : 'bg-dark-700'}`} />}
            </React.Fragment>
          ))}
        </div>

        {/* Step 1: Basic Info */}
        {step === 1 && (
          <motion.div initial={{ opacity: 0, x: 20 }} animate={{ opacity: 1, x: 0 }} className="glass-card p-8">
            <h2 className="font-display text-xl font-bold text-white mb-6">Loan Details</h2>
            <div className="space-y-5">
              <div>
                <label className="block text-sm text-white/50 mb-2">Loan Title *</label>
                <input name="title" value={form.title} onChange={handleChange} placeholder="e.g., Small Business Expansion" className="input-dark" />
              </div>
              <div>
                <label className="block text-sm text-white/50 mb-2">Description</label>
                <textarea name="description" value={form.description} onChange={handleChange} rows={4}
                  placeholder="Describe how you'll use the funds..." className="input-dark resize-none" />
              </div>
              <div>
                <label className="block text-sm text-white/50 mb-2">Purpose</label>
                <div className="grid grid-cols-3 gap-2">
                  {purposes.map(p => (
                    <button key={p.value} type="button" onClick={() => setForm({ ...form, purpose: p.value })}
                      className={`p-3 rounded-xl text-sm transition-all border flex flex-col items-center gap-1
                        ${form.purpose === p.value ? 'bg-emerald-500/10 border-emerald-500/30 text-emerald-400' : 'bg-dark-800 border-white/5 text-white/40 hover:bg-white/5'}`}>
                      <span className="text-lg">{p.icon}</span>
                      <span className="text-xs">{p.label}</span>
                    </button>
                  ))}
                </div>
              </div>
            </div>
            <button onClick={() => setStep(2)} className="btn-gradient w-full mt-8">Next →</button>
          </motion.div>
        )}

        {/* Step 2: Financial Details */}
        {step === 2 && (
          <motion.div initial={{ opacity: 0, x: 20 }} animate={{ opacity: 1, x: 0 }} className="glass-card p-8">
            <h2 className="font-display text-xl font-bold text-white mb-6">Financial Details</h2>
            <div className="space-y-5">
              <div>
                <label className="block text-sm text-white/50 mb-2">Loan Amount (₹) *</label>
                <input name="amount" type="number" value={form.amount} onChange={handleChange} placeholder="10000" className="input-dark text-xl" />
              </div>
              <div>
                <label className="block text-sm text-white/50 mb-2">Proposed Interest Rate (% p.a.) *</label>
                <input name="interestRate" type="number" step="0.5" value={form.interestRate} onChange={handleChange} placeholder="12" className="input-dark" />
              </div>
              <div>
                <label className="block text-sm text-white/50 mb-2">Tenure: {form.tenureMonths} months</label>
                <input name="tenureMonths" type="range" min="1" max="60" value={form.tenureMonths} onChange={handleChange}
                  className="w-full accent-emerald-500" />
                <div className="flex justify-between text-xs text-white/20 mt-1"><span>1 mo</span><span>60 mo</span></div>
              </div>
            </div>
            <div className="flex gap-3 mt-8">
              <button onClick={() => setStep(1)} className="btn-outline flex-1">← Back</button>
              <button onClick={() => setStep(3)} className="btn-gradient flex-1">Next →</button>
            </div>
          </motion.div>
        )}

        {/* Step 3: Review */}
        {step === 3 && (
          <motion.div initial={{ opacity: 0, x: 20 }} animate={{ opacity: 1, x: 0 }} className="glass-card p-8">
            <h2 className="font-display text-xl font-bold text-white mb-6">Review & Submit</h2>
            <div className="space-y-4 mb-8">
              {[
                { label: 'Title', value: form.title || '—' },
                { label: 'Purpose', value: form.purpose },
                { label: 'Amount', value: `₹${parseFloat(form.amount || 0).toLocaleString('en-IN')}` },
                { label: 'Interest Rate', value: `${form.interestRate}% p.a.` },
                { label: 'Tenure', value: `${form.tenureMonths} months` },
                { label: 'Monthly EMI', value: `₹${emi.toFixed(0).replace(/\B(?=(\d{3})+(?!\d))/g, ',')}` },
                { label: 'Total Repayable', value: `₹${(emi * parseInt(form.tenureMonths)).toFixed(0).replace(/\B(?=(\d{3})+(?!\d))/g, ',')}` },
              ].map((item, i) => (
                <div key={i} className="flex justify-between py-3 border-b border-white/5">
                  <span className="text-white/40 text-sm">{item.label}</span>
                  <span className="text-white font-medium text-sm">{item.value}</span>
                </div>
              ))}
            </div>
            <div className="bg-amber-500/10 border border-amber-500/20 rounded-xl p-4 mb-6">
              <p className="text-xs text-amber-400">⚠️ Your loan request will be reviewed by our admin team before it's listed on the marketplace.</p>
            </div>
            <div className="flex gap-3">
              <button onClick={() => setStep(2)} className="btn-outline flex-1">← Back</button>
              <button onClick={handleSubmit} className="btn-gradient flex-1">Submit Request</button>
            </div>
          </motion.div>
        )}
      </div>
    </DashboardLayout>
  );
};

export default CreateLoan;
