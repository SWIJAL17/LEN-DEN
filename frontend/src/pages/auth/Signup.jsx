import React, { useState } from "react";
import { useNavigate, Link } from "react-router-dom";
import { motion } from "framer-motion";
import { useAuth } from "../../context/AuthContext";
import { authAPI } from "../../services/api";
import toast, { Toaster } from "react-hot-toast";
import LendenLogo from "../../components/LendenLogo";

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
    <div className="min-h-screen flex items-center justify-center relative overflow-hidden noise-bg">
      <Toaster position="top-right" toastOptions={{ style: { background: '#1a1b2e', color: '#e0e0e8', border: '1px solid rgba(255,255,255,0.06)', borderRadius: '12px' } }} />
      <div className="fixed inset-0">
        <div className="absolute top-1/3 right-1/4 w-96 h-96 bg-violet-600/12 rounded-full blur-[120px] animate-glow-pulse" />
        <div className="absolute bottom-1/3 left-1/4 w-96 h-96 bg-fuchsia-500/8 rounded-full blur-[120px] animate-glow-pulse" style={{ animationDelay: '2s' }} />
      </div>

      <motion.div initial={{ opacity: 0, y: 30 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.6 }} className="relative z-10 w-full max-w-md px-6">
        <div className="glass-card p-8 sm:p-10">
          <div className="flex justify-center mb-8">
            <Link to="/">
              <LendenLogo size={56} />
            </Link>
          </div>
          <h1 className="font-display text-3xl font-bold text-white text-center mb-2">Create Account</h1>
          <p className="text-white/35 text-center mb-8">Join the Lenden community</p>

          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-sm text-white/45 mb-2">Full Name</label>
              <input type="text" name="name" value={form.name} onChange={handleChange} placeholder="John Doe" className="input-dark" />
            </div>
            <div>
              <label className="block text-sm text-white/45 mb-2">Email</label>
              <input type="email" name="email" value={form.email} onChange={handleChange} placeholder="you@example.com" className="input-dark" />
            </div>
            <div>
              <label className="block text-sm text-white/45 mb-2">I want to</label>
              <div className="grid grid-cols-2 gap-2">
                {['borrower', 'lender'].map(role => (
                  <motion.button key={role} type="button" whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.98 }}
                    onClick={() => setForm({ ...form, role })}
                    className={`px-4 py-3 rounded-xl text-sm font-medium transition-all border
                      ${form.role === role
                        ? 'bg-violet-500/10 border-violet-500/30 text-violet-400'
                        : 'bg-white/[0.03] border-white/[0.06] text-white/35 hover:text-white/60'}`}>
                    {role === 'borrower' ? '🏦 Borrow' : '💎 Lend'}
                  </motion.button>
                ))}
              </div>
            </div>
            <div>
              <label className="block text-sm text-white/45 mb-2">Password</label>
              <input type="password" name="password" value={form.password} onChange={handleChange} placeholder="••••••••" className="input-dark" />
            </div>
            <div>
              <label className="block text-sm text-white/45 mb-2">Confirm Password</label>
              <input type="password" name="confirmPassword" value={form.confirmPassword} onChange={handleChange} placeholder="••••••••" className="input-dark" />
            </div>
            <motion.button whileHover={{ scale: 1.01 }} whileTap={{ scale: 0.99 }} type="submit" disabled={loading}
              className="btn-gradient w-full !py-3.5 text-base disabled:opacity-50">
              <span>{loading ? 'Creating...' : 'Create Account'}</span>
            </motion.button>
          </form>

          <p className="text-center text-sm text-white/25 mt-8">
            Already have an account? <Link to="/login" className="text-violet-400 hover:text-violet-300 font-medium transition-colors">Sign In</Link>
          </p>
        </div>
      </motion.div>
    </div>
  );
};

export default Signup;
