import React from 'react';

const LendenLogo = ({ size = 40, className = '' }) => (
  <svg
    width={size}
    height={size}
    viewBox="0 0 64 64"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
    className={className}
  >
    <defs>
      <linearGradient id="lendenG1" x1="0%" y1="100%" x2="100%" y2="0%">
        <stop offset="0%" stopColor="#0d9488" />
        <stop offset="50%" stopColor="#14b8a6" />
        <stop offset="100%" stopColor="#2dd4bf" />
      </linearGradient>
      <linearGradient id="lendenG2" x1="0%" y1="100%" x2="100%" y2="0%">
        <stop offset="0%" stopColor="#0f766e" />
        <stop offset="100%" stopColor="#5eead4" />
      </linearGradient>
    </defs>
    {/* Circular swirl arrow */}
    <path
      d="M32 10 C16 10 8 20 8 32 C8 44 16 54 32 54 C44 54 52 46 54 38"
      stroke="url(#lendenG1)"
      strokeWidth="5"
      fill="none"
      strokeLinecap="round"
    />
    {/* Arrowhead on circular path */}
    <polygon points="52,34 58,40 50,43" fill="url(#lendenG1)" />
    {/* Upward growth arrow */}
    <line
      x1="20"
      y1="46"
      x2="44"
      y2="16"
      stroke="url(#lendenG2)"
      strokeWidth="5"
      strokeLinecap="round"
    />
    {/* Arrow tip */}
    <polygon points="44,16 46,26 36,19" fill="url(#lendenG2)" />
  </svg>
);

export default LendenLogo;
