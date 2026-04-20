import React, { useState } from "react";
import { useNavigate, Link } from "react-router-dom";
import { motion } from "framer-motion";
import { GoogleLogin } from "@react-oauth/google";
import { jwtDecode } from "jwt-decode";
import { useAuth } from "../../context/AuthContext";
import { authAPI } from "../../services/api";
import toast, { Toaster } from "react-hot-toast";
import LendenLogo from "../../components/LendenLogo";

const Login = () => {
  const { login } = useAuth();
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!email || !password) return toast.error("Fill in all fields");
    setLoading(true);
    try {
      const res = await authAPI.login({ email, password });
      login(res.data.user, res.data.token);
      toast.success("Welcome back!");
      navigate(res.data.user.role ? "/dashboard" : "/role");
    } catch (err) {
      toast.error(err.response?.data?.error || "Login failed. Is the backend running?");
    } finally {
      setLoading(false);
    }
  };

  const handleGoogleSuccess = async (credentialResponse) => {
    try {
      const decoded = jwtDecode(credentialResponse.credential);
      const res = await authAPI.google({ email: decoded.email, name: decoded.name, googleId: decoded.sub });
      login(res.data.user, res.data.token);
      toast.success(res.data.message || "Welcome!");
      navigate(res.data.user.role ? "/dashboard" : "/role");
    } catch (err) {
      try {
        const decoded = jwtDecode(credentialResponse.credential);
        login({ id: `google-${decoded.sub}`, name: decoded.name, email: decoded.email, role: null, walletBalance: 10000 }, "google-demo-token");
        toast.success("Signed in with Google! (Demo mode)");
        navigate("/role");
      } catch {
        toast.error("Google sign-in failed");
      }
    }
  };

  const handleDemoLogin = (role) => {
    const demoUsers = {
      borrower: { id: 'demo-b', name: 'Alex Borrower', email: 'demo@borrower.com', role: 'borrower', walletBalance: 15000 },
      lender: { id: 'demo-l', name: 'Sam Lender', email: 'demo@lender.com', role: 'lender', walletBalance: 50000 },
      admin: { id: 'demo-a', name: 'Platform Admin', email: 'admin@lenden.com', role: 'admin', walletBalance: 0 },
    };
    login(demoUsers[role], 'demo-token');
    toast.success(`Logged in as demo ${role}`);
    navigate('/dashboard');
  };

  return (
    <div className="min-h-screen flex items-center justify-center relative overflow-hidden noise-bg">
      <Toaster position="top-right" toastOptions={{ style: { background: '#1a1b2e', color: '#e0e0e8', border: '1px solid rgba(255,255,255,0.06)', borderRadius: '12px' } }} />
      
      {/* Background */}
      <div className="fixed inset-0">
        <div className="absolute top-1/4 left-1/4 w-96 h-96 bg-violet-600/12 rounded-full blur-[120px] animate-glow-pulse" />
        <div className="absolute bottom-1/4 right-1/4 w-96 h-96 bg-indigo-500/10 rounded-full blur-[120px] animate-glow-pulse" style={{ animationDelay: '2s' }} />
      </div>

      <motion.div initial={{ opacity: 0, y: 30 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.6 }} className="relative z-10 w-full max-w-md px-6">
        <div className="glass-card p-8 sm:p-10">
          {/* Logo */}
          <div className="flex justify-center mb-8">
            <Link to="/" className="flex items-center gap-3">
              <LendenLogo size={56} />
            </Link>
          </div>

          <h1 className="font-display text-3xl font-bold text-white text-center mb-2">Welcome Back</h1>
          <p className="text-white/35 text-center mb-8">Sign in to your Lenden account</p>

          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-sm text-white/45 mb-2">Email</label>
              <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="you@example.com" className="input-dark" />
            </div>
            <div>
              <label className="block text-sm text-white/45 mb-2">Password</label>
              <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} placeholder="••••••••" className="input-dark" />
            </div>
            <motion.button whileHover={{ scale: 1.01 }} whileTap={{ scale: 0.99 }} type="submit" disabled={loading}
              className="btn-gradient w-full !py-3.5 text-base disabled:opacity-50">
              <span>{loading ? 'Signing in...' : 'Sign In'}</span>
            </motion.button>
          </form>

          {/* Divider */}
          <div className="my-6 flex items-center gap-3">
            <div className="flex-1 h-px bg-white/[0.06]" />
            <span className="text-xs text-white/25 uppercase tracking-wider">or continue with</span>
            <div className="flex-1 h-px bg-white/[0.06]" />
          </div>

          {/* Google */}
          <div className="flex justify-center mb-6">
            <GoogleLogin onSuccess={handleGoogleSuccess} onError={() => toast.error("Google sign-in failed")}
              theme="filled_black" shape="pill" size="large" width="320" text="signin_with" />
          </div>

          {/* Demo */}
          <div className="my-4 flex items-center gap-3">
            <div className="flex-1 h-px bg-white/[0.04]" />
            <span className="text-[10px] text-white/15 uppercase tracking-widest">demo mode</span>
            <div className="flex-1 h-px bg-white/[0.04]" />
          </div>
          <div className="grid grid-cols-3 gap-2">
            {[
              { role: 'borrower', icon: '🏦', label: 'Borrower' },
              { role: 'lender', icon: '💎', label: 'Lender' },
              { role: 'admin', icon: '⚙️', label: 'Admin' },
            ].map(d => (
              <motion.button key={d.role} whileHover={{ scale: 1.03 }} whileTap={{ scale: 0.97 }}
                onClick={() => handleDemoLogin(d.role)}
                className="btn-outline !px-2 !py-2.5 text-xs">
                {d.icon} {d.label}
              </motion.button>
            ))}
          </div>

          <p className="text-center text-sm text-white/25 mt-8">
            Don't have an account?{' '}
            <Link to="/signup" className="text-violet-400 hover:text-violet-300 font-medium transition-colors">Sign Up</Link>
          </p>
        </div>
      </motion.div>
    </div>
  );
};

export default Login;
