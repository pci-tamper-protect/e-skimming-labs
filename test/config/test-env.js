/**
 * Test Environment Configuration
 *
 * All lab URLs use path-based routing through Traefik:
 *   prd  → https://labs.pcioasis.com/lab1
 *   stg  → https://labs.stg.pcioasis.com/lab1  (or http://localhost:8082/lab1 via proxy)
 *   local→ http://localhost:8080/lab1
 *
 * Usage:
 *   TEST_ENV=stg USE_PROXY=true npm test   # stg via gcloud proxy on port 8082
 *   TEST_ENV=prd npm test                  # production
 *   npm test                               # local docker-compose
 */

const TEST_ENV = process.env.TEST_ENV || 'local'
const fs = require('fs')
const path = require('path')

// Normalize proxy URLs to use localhost — Firebase only authorizes localhost, not 127.0.0.1
const normalizeUrl = (url) => {
  if (!url) return url
  return url.replace(/^https?:\/\/127\.0\.0\.1/, 'http://localhost')
}

// Load proxy configuration from .env.stg (shared with workflows)
// Falls back to environment variables or defaults
const getProxyConfig = () => {
  // Try environment variables first (set by workflows)
  if (process.env.PROXY_HOST && process.env.PROXY_PORT) {
    return {
      host: process.env.PROXY_HOST,
      port: process.env.PROXY_PORT
    }
  }

  // Try to read from .env.stg
  try {
    const envStgPath = path.join(__dirname, '../../.env.stg')
    if (fs.existsSync(envStgPath)) {
      const envContent = fs.readFileSync(envStgPath, 'utf8')
      const lines = envContent.split('\n')
      let proxyHost = null
      let proxyPort = null

      for (const line of lines) {
        if (line.trim().startsWith('#') || !line.trim()) continue
        if (line.includes('encrypted:')) continue

        const hostMatch = line.match(/^PROXY_HOST=(?:"([^"]+)"|([^\s#]+))/)
        if (hostMatch) {
          proxyHost = hostMatch[1] || hostMatch[2]
        }

        const portMatch = line.match(/^PROXY_PORT=(?:"([^"]+)"|([^\s#]+))/)
        if (portMatch) {
          proxyPort = portMatch[1] || portMatch[2]
        }
      }

      if (proxyHost && proxyPort) {
        return {
          host: proxyHost,
          port: parseInt(proxyPort, 10) || 8080
        }
      }
    }
  } catch (error) {
    // fall through to defaults
  }

  return {
    host: 'localhost',
    port: 8082
  }
}

const proxyConfig = getProxyConfig()

// Allow BASE_URL override for local testing (e.g., sidecar on port 9090)
const LOCAL_BASE_URL = process.env.BASE_URL || 'http://localhost:8080'

// stg base: proxy when USE_PROXY=true, otherwise public stg domain
const STG_BASE = (() => {
  if (process.env.USE_PROXY === 'true') {
    const url = process.env.PROXY_URL || `http://${proxyConfig.host}:${proxyConfig.port}`
    return normalizeUrl(url)
  }
  return 'https://labs.stg.pcioasis.com'
})()

const environments = {
  local: {
    homeIndex: LOCAL_BASE_URL,
    mainApp: 'http://localhost:5173',
    lab1: {
      vulnerable: `${LOCAL_BASE_URL}/lab1`,
      c2:         `${LOCAL_BASE_URL}/lab1/c2`,
      writeup:    `${LOCAL_BASE_URL}/lab-01-writeup`,
    },
    lab2: {
      vulnerable: `${LOCAL_BASE_URL}/lab2`,
      c2:         `${LOCAL_BASE_URL}/lab2/c2`,
      writeup:    `${LOCAL_BASE_URL}/lab-02-writeup`,
    },
    lab3: {
      vulnerable: `${LOCAL_BASE_URL}/lab3`,
      c2:         `${LOCAL_BASE_URL}/lab3/extension`,
      writeup:    `${LOCAL_BASE_URL}/lab-03-writeup`,
    },
    lab4: {
      vulnerable: `${LOCAL_BASE_URL}/lab4`,
      c2:         `${LOCAL_BASE_URL}/lab4/c2`,
      writeup:    `${LOCAL_BASE_URL}/lab-04-writeup`,
    },
  },
  stg: {
    // All URLs use path-based routing through Traefik (proxy or public stg domain).
    homeIndex: STG_BASE,
    mainApp: 'https://stg.pcioasis.com',
    firebaseProjectId: 'ui-firebase-pcioasis-stg',
    lab1: {
      vulnerable: `${STG_BASE}/lab1`,
      c2:         `${STG_BASE}/lab1/c2`,
      writeup:    `${STG_BASE}/lab-01-writeup`,
    },
    lab2: {
      vulnerable: `${STG_BASE}/lab2`,
      c2:         `${STG_BASE}/lab2/c2`,
      writeup:    `${STG_BASE}/lab-02-writeup`,
    },
    lab3: {
      vulnerable: `${STG_BASE}/lab3`,
      c2:         `${STG_BASE}/lab3/extension`,
      writeup:    `${STG_BASE}/lab-03-writeup`,
    },
    lab4: {
      vulnerable: `${STG_BASE}/lab4`,
      c2:         `${STG_BASE}/lab4/c2`,
      writeup:    `${STG_BASE}/lab-04-writeup`,
    },
  },
  prd: {
    // All URLs use path-based routing through labs.pcioasis.com (Traefik).
    homeIndex: 'https://labs.pcioasis.com',
    mainApp: 'https://www.pcioasis.com',
    firebaseProjectId: 'ui-firebase-pcioasis-prd',
    lab1: {
      vulnerable: 'https://labs.pcioasis.com/lab1',
      c2:         'https://labs.pcioasis.com/lab1/c2',
      writeup:    'https://labs.pcioasis.com/lab-01-writeup',
    },
    lab2: {
      vulnerable: 'https://labs.pcioasis.com/lab2',
      c2:         'https://labs.pcioasis.com/lab2/c2',
      writeup:    'https://labs.pcioasis.com/lab-02-writeup',
    },
    lab3: {
      vulnerable: 'https://labs.pcioasis.com/lab3',
      c2:         'https://labs.pcioasis.com/lab3/extension',
      writeup:    'https://labs.pcioasis.com/lab-03-writeup',
    },
    lab4: {
      vulnerable: 'https://labs.pcioasis.com/lab4',
      c2:         'https://labs.pcioasis.com/lab4/c2',
      writeup:    'https://labs.pcioasis.com/lab-04-writeup',
    },
  },
}

const currentEnv = environments[TEST_ENV]

if (!currentEnv) {
  throw new Error(`Invalid TEST_ENV: ${TEST_ENV}. Must be one of: ${Object.keys(environments).join(', ')}`)
}

// Helper to get C2 API endpoint
function getC2ApiEndpoint(labNumber) {
  const labKey = `lab${labNumber}`
  const c2Url = currentEnv[labKey]?.c2
  if (!c2Url) throw new Error(`C2 URL not found for ${labKey}`)
  return `${c2Url}/api/stolen`
}

// Helper to get C2 collect endpoint
function getC2CollectEndpoint(labNumber) {
  const labKey = `lab${labNumber}`
  const c2Url = currentEnv[labKey]?.c2
  if (!c2Url) throw new Error(`C2 URL not found for ${labKey}`)
  return `${c2Url}/collect`
}

console.log(`🧪 Test Environment: ${TEST_ENV}`)
if (process.env.USE_PROXY === 'true') {
  console.log(`🔗 Using gcloud proxy: ${STG_BASE}`)
}
console.log(`📍 Home Index: ${currentEnv.homeIndex}`)
if (currentEnv.mainApp) {
  console.log(`📍 Main App: ${currentEnv.mainApp}`)
}
if (currentEnv.firebaseProjectId) {
  console.log(`📍 Firebase Project: ${currentEnv.firebaseProjectId}`)
}
console.log(`📍 Lab 1 Vulnerable: ${currentEnv.lab1.vulnerable}`)
console.log(`📍 Lab 1 C2: ${currentEnv.lab1.c2}`)

module.exports = {
  TEST_ENV,
  environments,
  currentEnv,
  getC2ApiEndpoint,
  getC2CollectEndpoint,
}
