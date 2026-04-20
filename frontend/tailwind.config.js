/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./src/**/*.{js,jsx,ts,tsx}"],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
        display: ['Poppins', 'system-ui', 'sans-serif'],
      },
      colors: {
        dark: {
          50: '#f0f1f5',
          100: '#c8cad3',
          200: '#9a9dab',
          300: '#6b6f82',
          400: '#4a4e63',
          500: '#363a4f',
          600: '#2a2d3e',
          700: '#1e2030',
          800: '#181926',
          900: '#11111b',
          950: '#0a0a12',
        },
        accent: {
          primary: '#10b981',
          secondary: '#06b6d4',
          warning: '#f59e0b',
          danger: '#ef4444',
          purple: '#8b5cf6',
        }
      },
      borderRadius: {
        '2xl': '16px',
        '3xl': '24px',
      },
      backgroundImage: {
        'gradient-primary': 'linear-gradient(135deg, #10b981 0%, #06b6d4 100%)',
        'gradient-purple': 'linear-gradient(135deg, #8b5cf6 0%, #ec4899 100%)',
        'gradient-warm': 'linear-gradient(135deg, #f59e0b 0%, #ef4444 100%)',
        'gradient-dark': 'linear-gradient(180deg, #181926 0%, #11111b 100%)',
        'glass': 'linear-gradient(135deg, rgba(255,255,255,0.05) 0%, rgba(255,255,255,0.02) 100%)',
      },
      boxShadow: {
        'glass': '0 8px 32px rgba(0, 0, 0, 0.3)',
        'glow-green': '0 0 20px rgba(16, 185, 129, 0.3)',
        'glow-cyan': '0 0 20px rgba(6, 182, 212, 0.3)',
        'glow-purple': '0 0 20px rgba(139, 92, 246, 0.3)',
        'card': '0 4px 24px rgba(0, 0, 0, 0.2)',
        'card-hover': '0 8px 40px rgba(0, 0, 0, 0.3)',
      },
      animation: {
        'fade-in': 'fadeIn 0.5s ease-out',
        'slide-up': 'slideUp 0.5s ease-out',
        'pulse-slow': 'pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite',
        'shimmer': 'shimmer 2s linear infinite',
      },
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        slideUp: {
          '0%': { opacity: '0', transform: 'translateY(20px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
        shimmer: {
          '0%': { backgroundPosition: '-200% 0' },
          '100%': { backgroundPosition: '200% 0' },
        },
      },
    },
  },
  plugins: [],
};