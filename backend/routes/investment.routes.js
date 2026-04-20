const router = require('express').Router();
const auth = require('../middleware/auth');
const { requireRole } = require('../middleware/role');
const { fundLoan, getMyInvestments } = require('../controllers/investment.controller');

router.post('/', auth, requireRole('lender'), fundLoan);
router.get('/my', auth, requireRole('lender'), getMyInvestments);

module.exports = router;
