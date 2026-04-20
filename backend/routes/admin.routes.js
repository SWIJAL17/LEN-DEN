const router = require('express').Router();
const auth = require('../middleware/auth');
const { requireRole } = require('../middleware/role');
const c = require('../controllers/admin.controller');

router.get('/dashboard', auth, requireRole('admin'), c.getDashboard);
router.get('/loans/pending', auth, requireRole('admin'), c.getPendingLoans);
router.put('/loans/:id/approve', auth, requireRole('admin'), c.approveLoan);
router.put('/loans/:id/reject', auth, requireRole('admin'), c.rejectLoan);
router.get('/users', auth, requireRole('admin'), c.getUsers);
router.post('/users', auth, requireRole('admin'), c.createUser);

module.exports = router;
