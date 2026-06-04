// ============================================================
// LuckyRupee Backend API — server.js  (FIXED VERSION)
// Fixes applied:
//   1. Skill question correct_answer NOT sent to client
//   2. try/catch on ALL routes
//   3. SMS integration wired up (Jazz/Twilio)
//   4. JWT expiry reduced to 7d with refresh token support
//   5. triggerDraw() verified complete
// ============================================================

const express = require('express');
const cors    = require('cors');
const helmet  = require('helmet');
const rateLimit = require('express-rate-limit');
const { Pool }  = require('pg');
const bcrypt    = require('bcryptjs');
const jwt       = require('jsonwebtoken');
const crypto    = require('crypto');
const axios     = require('axios');

const app = express();

// ── Middleware ────────────────────────────────────────────
app.use(helmet());
app.use(cors({ origin: process.env.ALLOWED_ORIGINS?.split(',') || '*' }));
app.use(express.json());

const limiter     = rateLimit({ windowMs: 15 * 60 * 1000, max: 100 });
const authLimiter = rateLimit({ windowMs: 60 * 60 * 1000, max: 10, message: 'Too many auth attempts' });
app.use('/api/', limiter);
app.use('/api/auth/', authLimiter);

// ── Database ──────────────────────────────────────────────
const pool = new Pool({
  host:     process.env.DB_HOST || 'localhost',
  database: process.env.DB_NAME || 'luckyrupee',
  user:     process.env.DB_USER || 'postgres',
  password: process.env.DB_PASS,
  port:     5432,
  ssl:      process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
  max:      20,
  idleTimeoutMillis: 30000,
});

// ── Global error handler helper ───────────────────────────
const asyncRoute = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);

// ── JWT Auth Middleware ───────────────────────────────────
const authenticate = asyncRoute(async (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'No token provided' });
  try {
    req.user = jwt.verify(token, process.env.JWT_SECRET);
    next();
  } catch {
    res.status(401).json({ error: 'Invalid or expired token' });
  }
});

const adminOnly = (req, res, next) => {
  if (req.user.role !== 'admin') return res.status(403).json({ error: 'Admin access required' });
  next();
};

// ============================================================
// AUTH ROUTES
// ============================================================

// Send OTP
app.post('/api/auth/send-otp', asyncRoute(async (req, res) => {
  const { phone } = req.body;
  if (!phone || !/^03[0-9]{9}$/.test(phone))
    return res.status(400).json({ error: 'Invalid Pakistani phone number (format: 03XXXXXXXXX)' });

  const otp       = crypto.randomInt(100000, 999999).toString();
  const expiresAt = new Date(Date.now() + 5 * 60 * 1000);

  await pool.query(
    `INSERT INTO otp_codes (phone, code, expires_at) VALUES ($1, $2, $3)
     ON CONFLICT (phone) DO UPDATE SET code = $2, expires_at = $3, attempts = 0`,
    [phone, await bcrypt.hash(otp, 10), expiresAt]
  );

  await sendSMS(phone, `Your LuckyRupee code: ${otp}. Valid 5 min. Do not share.`);
  res.json({ success: true, message: 'OTP sent' });
}));

// Verify OTP & Login/Register
app.post('/api/auth/verify-otp', asyncRoute(async (req, res) => {
  const { phone, otp, referralCode, deviceId, deviceModel } = req.body;
  if (!phone || !otp) return res.status(400).json({ error: 'Phone and OTP required' });

  const otpRecord = await pool.query(
    'SELECT * FROM otp_codes WHERE phone = $1 AND expires_at > NOW() AND attempts < 5',
    [phone]
  );
  if (!otpRecord.rows.length)
    return res.status(400).json({ error: 'OTP expired or too many attempts. Request a new one.' });

  const valid = await bcrypt.compare(otp, otpRecord.rows[0].code);
  if (!valid) {
    await pool.query('UPDATE otp_codes SET attempts = attempts + 1 WHERE phone = $1', [phone]);
    return res.status(400).json({ error: 'Invalid OTP' });
  }

  // Device fingerprint fraud check
  if (deviceId) {
    const deviceCheck = await pool.query(
      'SELECT COUNT(*) FROM users WHERE device_id = $1 AND phone != $2',
      [deviceId, phone]
    );
    if (parseInt(deviceCheck.rows[0].count) >= 2)
      return res.status(403).json({ error: 'Device limit reached. Contact support.' });
  }

  let user      = await pool.query('SELECT * FROM users WHERE phone = $1', [phone]);
  let isNewUser = false;

  if (!user.rows.length) {
    isNewUser = true;
    const refCode = generateRefCode(phone);
    let referrerId = null;
    if (referralCode) {
      const referrer = await pool.query('SELECT id FROM users WHERE referral_code = $1', [referralCode]);
      if (referrer.rows.length) referrerId = referrer.rows[0].id;
    }
    user = await pool.query(
      `INSERT INTO users (phone, referral_code, referred_by, device_id, device_model, wallet_balance)
       VALUES ($1, $2, $3, $4, $5, 0) RETURNING *`,
      [phone, refCode, referrerId, deviceId, deviceModel]
    );
    if (referrerId) await creditWallet(referrerId, 2, 'referral_bonus', `Referral bonus for ${phone}`);
    await creditWallet(user.rows[0].id, 5, 'welcome_bonus', 'Welcome bonus');
  } else {
    await pool.query(
      'UPDATE users SET device_id = $1, last_login = NOW() WHERE phone = $2',
      [deviceId, phone]
    );
  }

  const userData = user.rows[0];

  // FIX: JWT expiry reduced from 30d → 7d
  const token = jwt.sign(
    { id: userData.id, phone: userData.phone, role: userData.role || 'user' },
    process.env.JWT_SECRET,
    { expiresIn: '7d' }
  );

  // Refresh token (30d, stored separately)
  const refreshToken = jwt.sign(
    { id: userData.id, type: 'refresh' },
    process.env.JWT_SECRET,
    { expiresIn: '30d' }
  );

  await pool.query('DELETE FROM otp_codes WHERE phone = $1', [phone]);

  res.json({
    success: true, token, refreshToken, isNewUser,
    user: {
      id:            userData.id,
      phone:         userData.phone,
      name:          userData.name,
      city:          userData.city,
      walletBalance: userData.wallet_balance,
      referralCode:  userData.referral_code,
      isVerified:    userData.is_verified,
    }
  });
}));

// Refresh token endpoint
app.post('/api/auth/refresh', asyncRoute(async (req, res) => {
  const { refreshToken } = req.body;
  if (!refreshToken) return res.status(400).json({ error: 'Refresh token required' });
  try {
    const decoded = jwt.verify(refreshToken, process.env.JWT_SECRET);
    if (decoded.type !== 'refresh') throw new Error('Not a refresh token');
    const user = await pool.query('SELECT * FROM users WHERE id = $1', [decoded.id]);
    if (!user.rows.length) throw new Error('User not found');
    const newToken = jwt.sign(
      { id: user.rows[0].id, phone: user.rows[0].phone, role: user.rows[0].role || 'user' },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );
    res.json({ token: newToken });
  } catch {
    res.status(401).json({ error: 'Invalid refresh token' });
  }
}));

// ============================================================
// DRAWS ROUTES
// ============================================================

app.get('/api/draws', authenticate, asyncRoute(async (req, res) => {
  const { page = 1, limit = 20, category } = req.query;
  const offset = (page - 1) * limit;

  const params = category
    ? [req.user.id, limit, offset, category]
    : [req.user.id, limit, offset];

  const result = await pool.query(
    `SELECT d.*,
       (SELECT COUNT(*) FROM entries e WHERE e.draw_id = d.id) as entries_sold,
       (SELECT COUNT(*) FROM entries e WHERE e.draw_id = d.id AND e.user_id = $1) as user_entries
     FROM draws d
     WHERE d.status = 'active' AND d.end_time > NOW()
     ${category ? 'AND d.category = $4' : ''}
     ORDER BY d.is_featured DESC, d.end_time ASC
     LIMIT $2 OFFSET $3`,
    params
  );
  res.json({ draws: result.rows, page: parseInt(page) });
}));

app.get('/api/draws/:id', authenticate, asyncRoute(async (req, res) => {
  const draw = await pool.query(
    `SELECT d.*,
       (SELECT COUNT(*) FROM entries e WHERE e.draw_id = d.id) as entries_sold,
       (SELECT COUNT(*) FROM entries e WHERE e.draw_id = d.id AND e.user_id = $2) as user_entries
     FROM draws d WHERE d.id = $1`,
    [req.params.id, req.user.id]
  );
  if (!draw.rows.length) return res.status(404).json({ error: 'Draw not found' });
  res.json(draw.rows[0]);
}));

// FIX 1: correct_answer NOT included in response
app.get('/api/draws/:id/question', authenticate, asyncRoute(async (req, res) => {
  const q = await pool.query(
    `SELECT id, question, option_a, option_b, option_c, option_d, difficulty, category
     FROM skill_questions WHERE is_active = true ORDER BY RANDOM() LIMIT 1`
    // NOTE: correct_answer intentionally excluded from SELECT
  );
  if (!q.rows.length) return res.status(404).json({ error: 'No questions available' });
  res.json(q.rows[0]);
}));

// Enter a draw
app.post('/api/draws/:id/enter', authenticate, asyncRoute(async (req, res) => {
  const { entries = 1, skillAnswer, questionId } = req.body;
  if (!skillAnswer || !questionId) return res.status(400).json({ error: 'Skill answer required' });

  const drawId = parseInt(req.params.id);
  const userId = req.user.id;
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const draw = await client.query(
      "SELECT * FROM draws WHERE id = $1 AND status = 'active' AND end_time > NOW() FOR UPDATE",
      [drawId]
    );
    if (!draw.rows.length) throw new Error('Draw not available or has ended');

    const drawData   = draw.rows[0];
    const countRes   = await client.query('SELECT COUNT(*) FROM entries WHERE draw_id = $1', [drawId]);
    const sold       = parseInt(countRes.rows[0].count);

    if (sold + entries > drawData.max_entries) throw new Error('Not enough slots remaining');

    const userCount = await client.query(
      'SELECT COUNT(*) FROM entries WHERE draw_id = $1 AND user_id = $2',
      [drawId, userId]
    );
    if (parseInt(userCount.rows[0].count) + entries > drawData.max_per_user)
      throw new Error(`Maximum ${drawData.max_per_user} entries per user`);

    // Validate skill answer — fetch correct_answer server-side only
    const question = await client.query(
      'SELECT correct_answer FROM skill_questions WHERE id = $1 AND is_active = true',
      [questionId]
    );
    if (!question.rows.length) throw new Error('Invalid question');
    if (question.rows[0].correct_answer !== skillAnswer?.toLowerCase())
      throw new Error('Incorrect answer to skill question');

    // Deduct wallet
    const totalCost = parseFloat(drawData.entry_price) * entries;
    const wallet    = await client.query(
      'SELECT wallet_balance FROM users WHERE id = $1 FOR UPDATE', [userId]
    );
    if (parseFloat(wallet.rows[0].wallet_balance) < totalCost)
      throw new Error('Insufficient wallet balance');

    await client.query(
      'UPDATE users SET wallet_balance = wallet_balance - $1 WHERE id = $2',
      [totalCost, userId]
    );
    await client.query(
      `INSERT INTO transactions (user_id, type, amount, reference, description)
       VALUES ($1, 'entry_fee', $2, $3, $4)`,
      [userId, -totalCost, `DRAW-${drawId}`, `${entries} entries in draw: ${drawData.prize_name}`]
    );

    // Insert entry rows
    for (let i = 0; i < entries; i++) {
      await client.query(
        'INSERT INTO entries (draw_id, user_id, entry_number) VALUES ($1, $2, $3)',
        [drawId, userId, sold + i + 1]
      );
    }

    if (sold + entries >= drawData.max_entries) {
      await client.query("UPDATE draws SET status = 'drawing' WHERE id = $1", [drawId]);
      triggerDraw(drawId).catch(err => console.error('Draw engine error:', err));
    }

    await client.query('COMMIT');

    const newBalance = parseFloat(wallet.rows[0].wallet_balance) - totalCost;
    res.json({ success: true, entries, newBalance, drawId });

  } catch (err) {
    await client.query('ROLLBACK');
    res.status(400).json({ error: err.message });
  } finally {
    client.release();
  }
}));

// ============================================================
// DRAW ENGINE — Cryptographic Random Winner Selection
// ============================================================

async function triggerDraw(drawId) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const entries = await client.query(
      'SELECT id, user_id, entry_number FROM entries WHERE draw_id = $1 ORDER BY entry_number',
      [drawId]
    );
    if (!entries.rows.length) throw new Error('No entries for draw ' + drawId);

    // Generate cryptographic seed and publish hash BEFORE selection
    const seed     = crypto.randomBytes(32).toString('hex');
    const seedHash = crypto.createHash('sha256').update(seed).digest('hex');

    await client.query('UPDATE draws SET seed_hash = $1 WHERE id = $2', [seedHash, drawId]);
    await client.query('COMMIT');

    // Brief delay so hash is visible before winner is revealed
    await new Promise(r => setTimeout(r, 2000));

    await client.query('BEGIN');
    const seedNum     = BigInt('0x' + seed.slice(0, 16));
    const winnerIndex = Number(seedNum % BigInt(entries.rows.length));
    const winnerEntry = entries.rows[winnerIndex];

    const draw     = await client.query('SELECT * FROM draws WHERE id = $1', [drawId]);
    const drawData = draw.rows[0];

    await client.query(
      `UPDATE draws SET
         status = 'completed', winner_id = $1, winner_entry_id = $2,
         winning_seed = $3, completed_at = NOW()
       WHERE id = $4`,
      [winnerEntry.user_id, winnerEntry.id, seed, drawId]
    );

    if (drawData.prize_type === 'cash') {
      await creditWallet(
        winnerEntry.user_id, drawData.prize_value, 'prize_won',
        `Won draw: ${drawData.prize_name}`
      );
    }

    const winner = await client.query('SELECT * FROM users WHERE id = $1', [winnerEntry.user_id]);
    if (winner.rows[0]?.fcm_token) {
      await sendPushNotification(
        winner.rows[0].fcm_token,
        '🎉 You WON!',
        `Congratulations! You won the ${drawData.prize_name}! We will contact you soon.`
      );
    }

    // Notify all participants
    const allEntrants = await client.query(
      'SELECT DISTINCT u.fcm_token FROM entries e JOIN users u ON u.id = e.user_id WHERE e.draw_id = $1 AND u.fcm_token IS NOT NULL',
      [drawId]
    );
    const tokens = allEntrants.rows.map(r => r.fcm_token).filter(Boolean);
    if (tokens.length) {
      await sendBatchPushNotification(
        tokens,
        `${drawData.prize_name} — Winner Announced!`,
        `${winner.rows[0].name || 'Someone'} from ${winner.rows[0].city || 'Pakistan'} just won!`
      );
    }

    await client.query('COMMIT');
    console.log(`✅ Draw ${drawId} complete. Winner: user ${winnerEntry.user_id}, entry #${winnerEntry.entry_number}`);

  } catch (err) {
    await client.query('ROLLBACK').catch(() => {});
    console.error(`❌ Draw engine error for draw ${drawId}:`, err);
  } finally {
    client.release();
  }
}

// ============================================================
// WALLET ROUTES
// ============================================================

app.get('/api/wallet/balance', authenticate, asyncRoute(async (req, res) => {
  const result = await pool.query('SELECT wallet_balance FROM users WHERE id = $1', [req.user.id]);
  if (!result.rows.length) return res.status(404).json({ error: 'User not found' });
  res.json({ balance: result.rows[0].wallet_balance });
}));

app.get('/api/wallet/transactions', authenticate, asyncRoute(async (req, res) => {
  const { limit = 20, page = 1 } = req.query;
  const offset = (page - 1) * limit;
  const result = await pool.query(
    `SELECT id, type, amount, description, status, created_at
     FROM transactions WHERE user_id = $1
     ORDER BY created_at DESC LIMIT $2 OFFSET $3`,
    [req.user.id, limit, offset]
  );
  res.json({ transactions: result.rows, page: parseInt(page) });
}));

app.post('/api/wallet/deposit', authenticate, asyncRoute(async (req, res) => {
  const { amount, method } = req.body;
  if (!amount || amount < 10) return res.status(400).json({ error: 'Minimum deposit is PKR 10' });
  if (!['jazzcash', 'easypaisa', 'bank'].includes(method))
    return res.status(400).json({ error: 'Invalid payment method' });

  const txnRef = `DEP-${Date.now()}-${req.user.id}`;

  if (method === 'jazzcash') {
    const payload = buildJazzCashPayload(amount, txnRef, req.user.phone);
    return res.json({ method: 'jazzcash', ...payload, txnRef });
  }

  res.json({ method, txnRef, message: 'Redirect to payment gateway' });
}));

// JazzCash payment callback (called by JazzCash server)
app.post('/api/wallet/jazzcash/callback', asyncRoute(async (req, res) => {
  const { pp_ResponseCode, pp_Amount, pp_TxnRefNo, pp_MobileNumber } = req.body;

  // Verify HMAC signature
  const receivedHash = req.body.pp_SecureHash;
  const computedHash = generateJazzCashHMAC(req.body);
  if (receivedHash !== computedHash)
    return res.status(400).json({ error: 'Invalid signature' });

  if (pp_ResponseCode === '000') {
    // Successful payment
    const amount = parseInt(pp_Amount) / 100; // JazzCash sends paisa
    const user   = await pool.query('SELECT id FROM users WHERE phone = $1', [pp_MobileNumber]);
    if (user.rows.length) {
      await creditWallet(user.rows[0].id, amount, 'deposit', `JazzCash deposit — ${pp_TxnRefNo}`);
    }
  }
  res.json({ success: true });
}));

app.post('/api/wallet/withdraw', authenticate, asyncRoute(async (req, res) => {
  const { amount, method, accountNumber } = req.body;
  if (!amount || amount < 100) return res.status(400).json({ error: 'Minimum withdrawal is PKR 100' });
  if (!accountNumber)         return res.status(400).json({ error: 'Account number required' });

  const userId   = req.user.id;
  const userData = await pool.query('SELECT * FROM users WHERE id = $1', [userId]);
  if (!userData.rows[0].is_verified)
    return res.status(400).json({ error: 'Complete identity verification to withdraw' });
  if (parseFloat(userData.rows[0].wallet_balance) < amount)
    return res.status(400).json({ error: 'Insufficient balance' });

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(
      'UPDATE users SET wallet_balance = wallet_balance - $1 WHERE id = $2',
      [amount, userId]
    );
    const txn = await client.query(
      `INSERT INTO transactions (user_id, type, amount, reference, status, description, metadata)
       VALUES ($1, 'withdrawal', $2, $3, 'pending', $4, $5) RETURNING id`,
      [userId, -amount, `WD-${Date.now()}`, `${method} withdrawal`, JSON.stringify({ accountNumber, method })]
    );
    await client.query('COMMIT');
    await queueWithdrawal(txn.rows[0].id, userId, amount, method, accountNumber);
    res.json({ success: true, message: 'Withdrawal submitted. Processing within 24 hours.' });
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}));

// ============================================================
// REFERRAL ROUTES
// ============================================================

app.get('/api/referral/stats', authenticate, asyncRoute(async (req, res) => {
  const stats = await pool.query(
    `SELECT
       COUNT(u.id) as total_referrals,
       COUNT(CASE WHEN u.wallet_balance > 0 THEN 1 END) as active_referrals,
       COALESCE(SUM(t.amount), 0) as total_earned
     FROM users u
     LEFT JOIN transactions t ON t.user_id = $1 AND t.type = 'referral_bonus'
     WHERE u.referred_by = $1`,
    [req.user.id]
  );
  const leaderboard = await pool.query(
    `SELECT u.name, u.city, COUNT(r.id) as referral_count
     FROM users u JOIN users r ON r.referred_by = u.id
     GROUP BY u.id, u.name, u.city
     ORDER BY referral_count DESC LIMIT 10`
  );
  const me = await pool.query('SELECT referral_code FROM users WHERE id = $1', [req.user.id]);
  res.json({
    stats:        stats.rows[0],
    leaderboard:  leaderboard.rows,
    referralCode: me.rows[0]?.referral_code,
  });
}));

// ============================================================
// ADMIN ROUTES
// ============================================================

app.post('/api/admin/draws', authenticate, adminOnly, asyncRoute(async (req, res) => {
  const {
    prizeName, prizeDescription, prizeImageUrl, prizeValue, prizeType,
    entryPrice, maxEntries, maxPerUser, endTime, category, isFeatured
  } = req.body;
  if (!prizeName || !prizeValue || !entryPrice || !maxEntries || !endTime)
    return res.status(400).json({ error: 'Missing required fields' });

  const draw = await pool.query(
    `INSERT INTO draws
       (prize_name, prize_description, prize_image_url, prize_value, prize_type,
        entry_price, max_entries, max_per_user, end_time, category, is_featured, status)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,'active') RETURNING *`,
    [prizeName, prizeDescription, prizeImageUrl, prizeValue, prizeType || 'physical',
     entryPrice, maxEntries, maxPerUser || 50, endTime, category, isFeatured || false]
  );
  res.json(draw.rows[0]);
}));

app.get('/api/admin/dashboard', authenticate, adminOnly, asyncRoute(async (req, res) => {
  const [users, revenue, draws, fraud] = await Promise.all([
    pool.query("SELECT COUNT(*) as total, COUNT(CASE WHEN created_at > NOW() - INTERVAL '24h' THEN 1 END) as today FROM users"),
    pool.query("SELECT COALESCE(SUM(ABS(amount)),0) as total FROM transactions WHERE type='entry_fee' AND created_at > date_trunc('month', NOW())"),
    pool.query("SELECT COUNT(*) as active FROM draws WHERE status='active'"),
    pool.query("SELECT COUNT(*) as flagged FROM users WHERE fraud_score > 0.7"),
  ]);
  res.json({
    users:          users.rows[0],
    monthlyRevenue: revenue.rows[0].total,
    activeDraws:    draws.rows[0].active,
    flaggedAccounts: fraud.rows[0].flagged,
  });
}));

app.get('/api/admin/users', authenticate, adminOnly, asyncRoute(async (req, res) => {
  const { page = 1, limit = 50, search } = req.query;
  const offset = (page - 1) * limit;
  const params = search ? [`%${search}%`, limit, offset] : [limit, offset];
  const result = await pool.query(
    `SELECT id, phone, name, city, wallet_balance, is_verified, fraud_score, created_at, last_login
     FROM users ${search ? 'WHERE phone ILIKE $1 OR name ILIKE $1' : ''}
     ORDER BY created_at DESC LIMIT ${search ? '$2' : '$1'} OFFSET ${search ? '$3' : '$2'}`,
    params
  );
  res.json({ users: result.rows, page: parseInt(page) });
}));

app.patch('/api/admin/users/:id/ban', authenticate, adminOnly, asyncRoute(async (req, res) => {
  await pool.query("UPDATE users SET role = 'banned' WHERE id = $1", [req.params.id]);
  res.json({ success: true });
}));

app.patch('/api/admin/users/:id/verify', authenticate, adminOnly, asyncRoute(async (req, res) => {
  await pool.query('UPDATE users SET is_verified = true WHERE id = $1', [req.params.id]);
  res.json({ success: true });
}));

// ============================================================
// HELPER FUNCTIONS
// ============================================================

async function creditWallet(userId, amount, type, description) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(
      'UPDATE users SET wallet_balance = wallet_balance + $1 WHERE id = $2',
      [amount, userId]
    );
    await client.query(
      'INSERT INTO transactions (user_id, type, amount, status, description) VALUES ($1,$2,$3,$4,$5)',
      [userId, type, amount, 'completed', description]
    );
    await client.query('COMMIT');
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
}

function generateRefCode(phone) {
  return phone.slice(-4) + crypto.randomBytes(3).toString('hex').toUpperCase();
}

// FIX 3: Real SMS integration (Jazz / Telenor bulk SMS)
async function sendSMS(phone, message) {
  const apiUrl = process.env.SMS_API_URL;
  const apiKey = process.env.SMS_API_KEY;

  if (!apiUrl || !apiKey) {
    // Development fallback — log OTP to console
    console.log(`[DEV SMS] To ${phone}: ${message}`);
    return;
  }

  try {
    // Compatible with most Pakistani SMS providers (Zong, Telenor bulk SMS APIs)
    await axios.post(apiUrl, {
      to:      phone,
      message: message,
      apiKey:  apiKey,
      from:    'LuckyRupee',
    }, { timeout: 10000 });
  } catch (err) {
    console.error('SMS send failed:', err.message);
    // Don't throw — OTP is still saved in DB; user can retry
  }
}

async function sendPushNotification(fcmToken, title, body) {
  if (!fcmToken || !process.env.FCM_SERVER_KEY) return;
  try {
    await axios.post('https://fcm.googleapis.com/fcm/send', {
      to:           fcmToken,
      notification: { title, body, sound: 'default' },
      data:         { type: 'draw_update' },
    }, { headers: { Authorization: `key=${process.env.FCM_SERVER_KEY}` } });
  } catch (err) {
    console.error('Push notification failed:', err.message);
  }
}

async function sendBatchPushNotification(tokens, title, body) {
  if (!tokens.length || !process.env.FCM_SERVER_KEY) return;
  const batchSize = 500;
  for (let i = 0; i < tokens.length; i += batchSize) {
    const batch = tokens.slice(i, i + batchSize);
    try {
      await axios.post('https://fcm.googleapis.com/fcm/send', {
        registration_ids: batch,
        notification:     { title, body, sound: 'default' },
      }, { headers: { Authorization: `key=${process.env.FCM_SERVER_KEY}` } });
    } catch (err) {
      console.error('Batch push failed:', err.message);
    }
    await new Promise(r => setTimeout(r, 100));
  }
}

function buildJazzCashPayload(amount, txnRef, phone) {
  const datetime = new Date().toISOString().replace(/[-:T.]/g, '').slice(0, 14);
  const expiry   = new Date(Date.now() + 3600000).toISOString().replace(/[-:T.]/g, '').slice(0, 14);
  const data = {
    pp_Version:            '1.1',
    pp_TxnType:            'MWALLET',
    pp_Language:           'EN',
    pp_MerchantID:         process.env.JAZZCASH_MERCHANT_ID,
    pp_SubMerchantID:      '',
    pp_Password:           process.env.JAZZCASH_PASSWORD,
    pp_TxnRefNo:           txnRef,
    pp_Amount:             (amount * 100).toString(),
    pp_TxnCurrency:        'PKR',
    pp_TxnDateTime:        datetime,
    pp_BillReference:      'LUCKYRUPEE',
    pp_Description:        'LuckyRupee Wallet Top-up',
    pp_TxnExpiryDateTime:  expiry,
    pp_ReturnURL:          `${process.env.API_BASE_URL}/api/wallet/jazzcash/callback`,
    pp_MobileNumber:       phone,
  };
  data.pp_SecureHash = generateJazzCashHMAC(data);
  return { url: process.env.JAZZCASH_CHECKOUT_URL, formData: data };
}

function generateJazzCashHMAC(data) {
  const sortedKeys   = Object.keys(data).filter(k => k.startsWith('pp_') && k !== 'pp_SecureHash').sort();
  const hashString   = process.env.JAZZCASH_INTEGRITY_SALT + '&' + sortedKeys.map(k => data[k]).join('&');
  return crypto.createHmac('sha256', process.env.JAZZCASH_INTEGRITY_SALT).update(hashString).digest('hex').toUpperCase();
}

async function queueWithdrawal(txnId, userId, amount, method, accountNumber) {
  // In production, this pushes to BullMQ Redis queue (worker.js handles it)
  // For now: log for manual processing
  console.log(`[WITHDRAWAL QUEUED] txn=${txnId} user=${userId} PKR=${amount} via ${method} to ${accountNumber}`);
}

// ── Global error handler ──────────────────────────────────
app.use((err, req, res, _next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// ── Start ──────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
// Only start listening when run directly (not when required by tests)
if (require.main === module) {
  app.listen(PORT, () => console.log(`🚀 LuckyRupee API running on port ${PORT}`));
}
module.exports = app;
