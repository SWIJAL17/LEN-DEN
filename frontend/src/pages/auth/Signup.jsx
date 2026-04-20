import React, { useState } from "react";
import { useNavigate, Link } from "react-router-dom";
import { motion } from "framer-motion";
import { useAuth } from "../../context/AuthContext";
import { authAPI } from "../../services/api";
import toast, { Toaster } from "react-hot-toast";

const Signup = () => {
  const { login } = useAuth();
  const navigate = useNavigate();
  const [form, setForm] = useState({ name: "", email: "", password: "", confirmPassword: "", role: "borrower" });
  const [loading, setLoading] = useState(false);

  const handleChange = (e) => setForm({ ...form, [e.target.name]: e.target.value });

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!form.name || !form.email || !form.password) return toast.error("Fill in all fields");
    if (form.password !== form.confirmPassword) return toast.error("Passwords don't match");
    if (form.password.length < 6) return toast.error("Password must be at least 6 characters");
    setLoading(true);
    try {
      const res = await authAPI.signup({ name: form.name, email: form.email, password: form.password, role: form.role });
      login(res.data.user, res.data.token);
      toast.success("Account created!");
      navigate("/dashboard");
    } catch (err) {
      toast.error(err.response?.data?.error || "Signup failed");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center relative overflow-hidden">
      <Toaster position="top-right" toastOptions={{ style: { background: '#1e2030', color: '#e0e0e8', border: '1px solid rgba(255,255,255,0.05)', borderRadius: '12px' } }} />
      <div className="absolute inset-0">
        <div className="absolute top-1/3 right-1/4 w-96 h-96 bg-purple-500/10 rounded-full blur-3xl animate-pulse-slow" />
        <div className="absolute bottom-1/3 left-1/4 w-96 h-96 bg-emerald-500/10 rounded-full blur-3xl animate-pulse-slow" style={{ animationDelay: '2s' }} />
      </div>

      <motion.div initial={{ opacity: 0, y: 30 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.6 }}
        className="relative z-10 w-full max-w-md px-6"
      >
        <div className="glass-card p-8 sm:p-10">
          <div className="flex justify-center mb-8">
            <div className="w-16 h-16 rounded-2xl bg-gradient-purple flex items-center justify-center shadow-glow-purple">
              <span className="text-3xl font-bold text-white font-display">M</span>
            </div>
          </div>
          <h1 className="font-display text-3xl font-bold text-white text-center mb-2">Create Account</h1>
          <p className="text-white/40 text-center mb-8">Join the micro-lending revolution</p>

          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-sm text-white/50 mb-2">Full Name</label>
              <input type="text" name="name" value={form.name} onChange={handleChange} placeholder="John Doe" className="input-dark" />
            </div>
            <div>
              <label className="block text-sm text-white/50 mb-2">Email</label>
              <input type="email" name="email" value={form.email} onChange={handleChange} placeholder="you@example.com" className="input-dark" />
            </div>
            <div>
              <label className="block text-sm text-white/50 mb-2">I want to</label>
              <div className="grid grid-cols-2 gap-2">
                {['borrower', 'lender'].map(role => (
                  <button key={role} type="button"
                    onClick={() => setForm({ ...form, role })}
                    className={`px-4 py-3 rounded-xl text-sm font-medium transition-all border
                      ${form.role === role 
                        ? 'bg-emerald-500/10 border-emerald-500/30 text-emerald-400' 
                        : 'bg-dark-800 border-white/5 text-white/40 hover:bg-white/5'}`}
                  >
                    {role === 'borrower' ? '🏦 Borrow' : '💎 Lend'}
                  </button>
                ))}
              </div>
            </div>
            <div>
              <label className="block text-sm text-white/50 mb-2">Password</label>
              <input type="password" name="password" value={form.password} onChange={handleChange} placeholder="••••••••" className="input-dark" />
            </div>
            <div>
              <label className="block text-sm text-white/50 mb-2">Confirm Password</label>
              <input type="password" name="confirmPassword" value={form.confirmPassword} onChange={handleChange} placeholder="••••••••" className="input-dark" />
            </div>
            <button type="submit" disabled={loading} className="btn-gradient-purple w-full !py-3.5 text-base disabled:opacity-50">
              {loading ? 'Creating...' : 'Create Account'}
            </button>
          </form>
          <p className="text-center text-sm text-white/30 mt-8">
            Already have an account? <Link to="/login" className="text-purple-400 hover:text-purple-300 font-medium transition-colors">Sign In</Link>
          </p>
        </div>
      </motion.div>
    </div>
  );
};

export default Signup;
