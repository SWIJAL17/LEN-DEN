import axios from "axios";

const api = axios.create({
  baseURL: "http://localhost:5000/api",
});

// Attach JWT token to every request
api.interceptors.request.use((config) => {
  const token = localStorage.getItem("ml_token");
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Handle auth errors globally
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem("ml_token");
      localStorage.removeItem("ml_user");
      if (window.location.pathname !== "/login") {
        window.location.href = "/login";
      }
    }
    return Promise.reject(error);
  }
);

export default api;

// ─── API Functions ───────────────────────────────────────────
export const authAPI = {
  signup: (data) => api.post("/auth/signup", data),
  login: (data) => api.post("/auth/login", data),
  google: (data) => api.post("/auth/google", data),
  setRole: (role) => api.put("/auth/role", { role }),
};

export const userAPI = {
  getProfile: () => api.get("/users/profile"),
  updateProfile: (data) => api.put("/users/profile", data),
  getStats: () => api.get("/users/stats"),
};

export const loanAPI = {
  create: (data) => api.post("/loans", data),
  getAll: (params) => api.get("/loans", { params }),
  getMy: () => api.get("/loans/my"),
  getDetails: (id) => api.get(`/loans/${id}`),
};

export const investmentAPI = {
  fund: (data) => api.post("/investments", data),
  getMy: () => api.get("/investments/my"),
};

export const repaymentAPI = {
  make: (data) => api.post("/repayments", data),
  getSchedule: (loanId) => api.get(`/repayments/${loanId}`),
};

export const walletAPI = {
  get: () => api.get("/wallet"),
  deposit: (amount) => api.post("/wallet/deposit", { amount }),
  withdraw: (amount) => api.post("/wallet/withdraw", { amount }),
};

export const adminAPI = {
  getDashboard: () => api.get("/admin/dashboard"),
  getPending: () => api.get("/admin/loans/pending"),
  approve: (id) => api.put(`/admin/loans/${id}/approve`),
  reject: (id, reason) => api.put(`/admin/loans/${id}/reject`, { reason }),
  getUsers: () => api.get("/admin/users"),
  createUser: (data) => api.post("/admin/users", data),
};