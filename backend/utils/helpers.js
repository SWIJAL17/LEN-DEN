// Calculate risk score based on loan parameters and borrower history
function calculateRiskScore(amount, tenureMonths, interestRate, creditScore = 650) {
  let score = 0;

  // Amount factor (higher amount = higher risk)
  if (amount > 50000) score += 3;
  else if (amount > 20000) score += 2;
  else score += 1;

  // Tenure factor (longer tenure = higher risk)
  if (tenureMonths > 24) score += 3;
  else if (tenureMonths > 12) score += 2;
  else score += 1;

  // Interest rate factor (higher rate often = higher risk borrower)
  if (interestRate > 20) score += 3;
  else if (interestRate > 12) score += 2;
  else score += 1;

  // Credit score factor
  if (creditScore < 500) score += 3;
  else if (creditScore < 700) score += 2;
  else score += 1;

  // Determine risk level
  if (score >= 10) return 'high';
  if (score >= 6) return 'medium';
  return 'low';
}

// Format currency
function formatCurrency(amount) {
  return parseFloat(amount).toFixed(2);
}

module.exports = { calculateRiskScore, formatCurrency };
