import React from 'react';
import Sidebar from './Sidebar';
import TopBar from './TopBar';
import { Toaster } from 'react-hot-toast';

const DashboardLayout = ({ title, children }) => {
  return (
    <div className="flex min-h-screen bg-dark-900">
      <Toaster
        position="top-right"
        toastOptions={{
          style: {
            background: '#1e2030',
            color: '#e0e0e8',
            border: '1px solid rgba(255,255,255,0.05)',
            borderRadius: '12px',
          },
          success: { iconTheme: { primary: '#10b981', secondary: '#fff' } },
          error: { iconTheme: { primary: '#ef4444', secondary: '#fff' } },
        }}
      />
      <Sidebar />
      <div className="flex-1 ml-64">
        <TopBar title={title} />
        <main className="p-8">
          {children}
        </main>
      </div>
    </div>
  );
};

export default DashboardLayout;
