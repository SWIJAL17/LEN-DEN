import React, { useState } from "react";
import { useNavigate, Link } from "react-router-dom";
import { motion } from "framer-motion";
import { GoogleLogin } from "@react-oauth/google";
import { jwtDecode } from "jwt-decode";
import { useAuth } from "../../context/AuthContext";
import { authAPI } from "../../services/api";
import toast, { Toaster } from "react-hot-toast";

const Login = () => {
  const { login } = useAuth();
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);

  // ─── Email/Password Login ──────────────────────────────────
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

  // ─── Google OAuth Login ────────────────────────────────────
  const handleGoogleSuccess = async (credentialResponse) => {
    try {
      const decoded = jwtDecode(credentialResponse.credential);
      const res = await authAPI.google({
        email: decoded.email,
        name: decoded.name,
        googleId: decoded.sub,
      });
      login(res.data.user, res.data.token);
      toast.success(res.data.message || "Welcome!");
      navigate(res.data.user.role ? "/dashboard" : "/role");
    } catch (err) {
      // If backend is not connected, use demo mode with Google info
      try {
        const decoded = jwtDecode(credentialResponse.credential);
        const mockUser = {
          id: `google-${decoded.sub}`,
          name: decoded.name,
          email: decoded.email,
          role: null,
          walletBalance: 10000,
        };
        login(mockUser, "google-demo-token");
        toast.success("Signed in with Google! (Demo mode)");
        navigate("/role");
      } catch {
        toast.error("Google sign-in failed");
      }
    }
  };

  // ─── Demo Login (for testing without backend) ──────────────
  const handleDemoLogin = (role) => {
    const demoUsers = {
      borrower: { id: 'demo-b', name: 'Alex Borrower', email: 'demo@borrower.com', role: 'borrower', walletBalance: 15000 },
      lender: { id: 'demo-l', name: 'Sam Lender', email: 'demo@lender.com', role: 'lender', walletBalance: 50000 },
      admin: { id: 'demo-a', name: 'Platform Admin', email: 'admin@microlend.com', role: 'admin', walletBalance: 0 },
    };
    login(demoUsers[role], 'demo-token');
    toast.success(`Logged in as demo ${role}`);
    navigate('/dashboard');
  };

  return (
    <div className="min-h-screen flex items-center justify-center relative overflow-hidden">
      <Toaster position="top-right" toastOptions={{ style: { background: '#1e2030', color: '#e0e0e8', border: '1px solid rgba(255,255,255,0.05)', borderRadius: '12px' } }} />
      
      {/* Background Glow Effects */}
      <div className="absolute inset-0">
        <div className="absolute top-1/4 left-1/4 w-96 h-96 bg-emerald-500/10 rounded-full blur-3xl animate-pulse-slow" />
        <div className="absolute bottom-1/4 right-1/4 w-96 h-96 bg-cyan-500/10 rounded-full blur-3xl animate-pulse-slow" style={{ animationDelay: '1.5s' }} />
        <div className="absolute top-1/2 left-1/2 w-64 h-64 bg-purple-500/5 rounded-full blur-3xl animate-pulse-slow" style={{ animationDelay: '3s' }} />
      </div>

      <motion.div
        initial={{ opacity: 0, y: 30 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.6 }}
        className="relative z-10 w-full max-w-md px-6"
      >
        <div className="glass-card p-8 sm:p-10">
          {/* Logo */}
          <div className="flex justify-center mb-8">
            <div className="w-16 h-16 rounded-2xl bg-gradient-primary flex items-center justify-center shadow-glow-green">
              <span className="text-3xl font-bold text-white font-display">M</span>
            </div>
          </div>

          <h1 className="font-display text-3xl font-bold text-white text-center mb-2">Welcome Back</h1>
          <p className="text-white/40 text-center mb-8">Sign in to your MicroLend account</p>

          {/* Email/Password Form */}
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-sm text-white/50 mb-2">Email</label>
              <input type="email" value={email} onChange={(e) => setEmail(e.target.value)}
                placeholder="you@example.com" className="input-dark" />
            </div>
            <div>
              <label className="block text-sm text-white/50 mb-2">Password</label>
              <input type="password" value={password} onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••" className="input-dark" />
            </div>
            <button type="submit" disabled={loading} className="btn-gradient w-full !py-3.5 text-base disabled:opacity-50">
              {loading ? 'Signing in...' : 'Sign In'}
            </button>
          </form>

          {/* Divider */}
          <div className="my-6 flex items-center gap-3">
            <div className="flex-1 h-px bg-white/10" />
            <span className="text-xs text-white/30 uppercase">or continue with</span>
            <div className="flex-1 h-px bg-white/10" />
          </div>

          {/* Google Sign In */}
          <div className="flex justify-center mb-4">
            <GoogleLogin
              onSuccess={handleGoogleSuccess}
              onError={() => toast.error("Google sign-in failed")}
              theme="filled_black"
              shape="pill"
              size="large"
              width="320"
              text="signin_with"
            />
          </div>

          {/* Demo Divider */}
          <div className="my-4 flex items-center gap-3">
            <div className="flex-1 h-px bg-white/5" />
            <span className="text-xs text-white/20 uppercase">demo mode</span>
            <div className="flex-1 h-px bg-white/5" />
          </div>

          {/* Demo Quick Login Buttons */}
          <div className="grid grid-cols-3 gap-2">
            <button onClick={() => handleDemoLogin('borrower')} className="btn-outline !px-2 !py-2.5 text-xs">
              🏦 Borrower
            </button>
            <button onClick={() => handleDemoLogin('lender')} className="btn-outline !px-2 !py-2.5 text-xs">
              💎 Lender
            </button>
            <button onClick={() => handleDemoLogin('admin')} className="btn-outline !px-2 !py-2.5 text-xs">
              ⚙️ Admin
            </button>
          </div>

          <p className="text-center text-sm text-white/30 mt-8">
            Don't have an account?{' '}
            <Link to="/signup" className="text-emerald-400 hover:text-emerald-300 font-medium transition-colors">
              Sign Up
            </Link>
          </p>
        </div>
      </motion.div>
    </div>
  );
};

export default Login;
