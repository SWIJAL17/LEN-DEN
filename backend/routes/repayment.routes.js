const router = require('express').Router();
const auth = require('../middleware/auth');
const { makeRepayment, getRepaymentSchedule } = require('../controllers/repayment.controller');

router.post('/', auth, makeRepayment);
router.get('/:loanId', auth, getRepaymentSchedule);

module.exports = router;
