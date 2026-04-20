const router = require('express').Router();
const auth = require('../middleware/auth');
const { signup, login, googleAuth, setRole } = require('../controllers/auth.controller');

router.post('/signup', signup);
router.post('/login', login);
router.post('/google', googleAuth);
router.put('/role', auth, setRole);

module.exports = router;
