const router = require('express').Router();
const auth = require('../middleware/auth');
const { requireRole } = require('../middleware/role');
const { createLoan, getAllLoans, getMyLoans, getLoanDetails } = require('../controllers/loan.controller');

router.post('/', auth, requireRole('borrower'), createLoan);
router.get('/', auth, getAllLoans);
router.get('/my', auth, getMyLoans);
router.get('/:id', auth, getLoanDetails);

module.exports = router;
