// Global error handler middleware
const errorHandler = (err, req, res, next) => {
  console.error('Error:', err.message);
  console.error('Stack:', err.stack);

  // PostgreSQL errors
  if (err.code === '23505') {
    return res.status(409).json({ error: 'Duplicate entry. This record already exists.' });
  }
  if (err.code === '23503') {
    return res.status(400).json({ error: 'Referenced record does not exist.' });
  }

  // Validation errors
  if (err.type === 'validation') {
    return res.status(400).json({ error: err.message, details: err.details });
  }

  // Default
  res.status(err.status || 500).json({
    error: err.message || 'Internal server error.',
  });
};

module.exports = errorHandler;
