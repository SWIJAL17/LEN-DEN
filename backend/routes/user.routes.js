const router = require('express').Router();
const auth = require('../middleware/auth');
const { getProfile, updateProfile, getStats } = require('../controllers/user.controller');

router.get('/profile', auth, getProfile);
router.put('/profile', auth, updateProfile);
router.get('/stats', auth, getStats);

module.exports = router;
