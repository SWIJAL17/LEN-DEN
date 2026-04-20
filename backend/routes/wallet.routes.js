const router = require('express').Router();
const auth = require('../middleware/auth');
const { getWallet, deposit, withdraw } = require('../controllers/wallet.controller');

router.get('/', auth, getWallet);
router.post('/deposit', auth, deposit);
router.post('/withdraw', auth, withdraw);

module.exports = router;
