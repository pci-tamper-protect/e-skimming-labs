/**
 * Test Environment Configuration
 *
 * This module provides environment-aware URLs for running tests against different deployments:
 * - local: Docker Compose on localhost
 * - stg: Staging deployment at labs.stg.pcioasis.com
 * - prd: Production deployment at labs.pcioasis.com
 *
 * Usage:
 *   Set TEST_ENV environment variable: TEST_ENV=stg npm test
 *   Defaults to 'local' if not set
 */

const TEST_ENV = process.env.TEST_ENV || 'local'
const fs = require('fs')
const path = require('path')

// Normalize URLs to use 127.0.0.1 instead of localhost for consistency
const normalizeUrl = (url) => {
  if (!url) return url
  return url.replace(/^https?:\/\/localhost/, 'http://127.0.0.1').replace(/^https?:\/\/127\.0\.0\.1/, 'http://127.0.0.1')
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
      // Parse .env file format (KEY="VALUE" or KEY=VALUE)
      const lines = envContent.split('\n')
      let proxyHost = null
      let proxyPort = null

      for (const line of lines) {
        // Skip comments and empty lines
        if (line.trim().startsWith('#') || !line.trim()) continue
        // Skip encrypted values
        if (line.includes('encrypted:')) continue

        // Match PROXY_HOST="value" or PROXY_HOST=value
        const hostMatch = line.match(/^PROXY_HOST=(?:"([^"]+)"|([^\s#]+))/)
        if (hostMatch) {
          proxyHost = hostMatch[1] || hostMatch[2]
        }

        // Match PROXY_PORT="value" or PROXY_PORT=value
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
    // If parsing fails or file doesn't exist, use defaults
  }

  // Defaults
  return {
    host: '127.0.0.1',
    port: 8080
  }
}

const proxyConfig = getProxyConfig()

const environments = {
  local: {
    homeIndex: 'http://localhost:8080',
    mainApp: 'http://localhost:5173',
    lab1: {
      vulnerable: 'http://localhost:8080/lab1',
      c2: 'http://localhost:8080/lab1/c2',
      writeup: 'http://localhost:8080/lab-01-writeup',
    },
    lab2: {
      vulnerable: 'http://localhost:8080/lab2',
      c2: 'http://localhost:8080/lab2/c2',
      writeup: 'http://localhost:8080/lab-02-writeup',
    },
    lab3: {
      vulnerable: 'http://localhost:8080/lab3',
      c2: 'http://localhost:8080/lab3/extension',
      writeup: 'http://localhost:8080/lab-03-writeup',
    },
  },
  stg: {
    // Use proxy URL if available (for CI/CD), otherwise use direct domain
    // When using proxy, all URLs go through the proxy (relative paths)
    // Construct proxy URL from config if PROXY_URL env var not set
    homeIndex: (() => {
      if (process.env.PROXY_URL && process.env.USE_PROXY === 'true') {
        return normalizeUrl(process.env.PROXY_URL)
      }
      // If USE_PROXY is true but PROXY_URL not set, construct from config
      if (process.env.USE_PROXY === 'true') {
        return `http://${proxyConfig.host}:${proxyConfig.port}`
      }
      return 'https://labs.stg.pcioasis.com'
    })(),
    mainApp: 'https://stg.pcioasis.com',
    firebaseProjectId: 'ui-firebase-pcioasis-stg',
    lab1: {
      // When using proxy, use relative paths through Traefik
      // Construct proxy URL from config if PROXY_URL env var not set
      vulnerable: (() => {
        if (process.env.PROXY_URL && process.env.USE_PROXY === 'true') {
          return `${process.env.PROXY_URL}/lab1`
        }
        if (process.env.USE_PROXY === 'true') {
          return `http://${proxyConfig.host}:${proxyConfig.port}/lab1`
        }
        return 'https://lab-01-basic-magecart-stg-mmwwcfi5za-uc.a.run.app'
      })(),
      c2: (() => {
        if (process.env.PROXY_URL && process.env.USE_PROXY === 'true') {
          return `${process.env.PROXY_URL}/lab1/c2`
        }
        if (process.env.USE_PROXY === 'true') {
          return `http://${proxyConfig.host}:${proxyConfig.port}/lab1/c2`
        }
        return 'https://lab-01-basic-magecart-stg-mmwwcfi5za-uc.a.run.app'
      })(),
      writeup: (() => {
        if (process.env.PROXY_URL && process.env.USE_PROXY === 'true') {
          return `${process.env.PROXY_URL}/lab-01-writeup`
        }
        if (process.env.USE_PROXY === 'true') {
          return `http://${proxyConfig.host}:${proxyConfig.port}/lab-01-writeup`
        }
        return 'https://labs.stg.pcioasis.com/lab-01-writeup'
      })(),
    },
    lab2: {
      vulnerable: (() => {
        if (process.env.PROXY_URL && process.env.USE_PROXY === 'true') {
          return `${process.env.PROXY_URL}/lab2`
        }
        if (process.env.USE_PROXY === 'true') {
          return `http://${proxyConfig.host}:${proxyConfig.port}/lab2`
        }
        return 'https://lab-02-dom-skimming-stg-mmwwcfi5za-uc.a.run.app'
      })(),
      c2: (() => {
        if (process.env.PROXY_URL && process.env.USE_PROXY === 'true') {
          return `${process.env.PROXY_URL}/lab2/c2`
        }
        if (process.env.USE_PROXY === 'true') {
          return `http://${proxyConfig.host}:${proxyConfig.port}/lab2/c2`
        }
        return 'https://lab-02-dom-skimming-c2-stg-mmwwcfi5za-uc.a.run.app'
      })(),
      writeup: (() => {
        if (process.env.PROXY_URL && process.env.USE_PROXY === 'true') {
          return `${process.env.PROXY_URL}/lab-02-writeup`
        }
        if (process.env.USE_PROXY === 'true') {
          return `http://${proxyConfig.host}:${proxyConfig.port}/lab-02-writeup`
        }
        return 'https://labs.stg.pcioasis.com/lab-02-writeup'
      })(),
    },
    lab3: {
      vulnerable: (() => {
        if (process.env.PROXY_URL && process.env.USE_PROXY === 'true') {
          return `${process.env.PROXY_URL}/lab3`
        }
        if (process.env.USE_PROXY === 'true') {
          return `http://${proxyConfig.host}:${proxyConfig.port}/lab3`
        }
        return 'https://lab-03-extension-hijacking-stg-mmwwcfi5za-uc.a.run.app'
      })(),
      c2: (() => {
        if (process.env.PROXY_URL && process.env.USE_PROXY === 'true') {
          return `${process.env.PROXY_URL}/lab3/extension`
        }
        if (process.env.USE_PROXY === 'true') {
          return `http://${proxyConfig.host}:${proxyConfig.port}/lab3/extension`
        }
        return 'https://lab-03-extension-hijacking-c2-stg-mmwwcfi5za-uc.a.run.app'
      })(),
      writeup: (() => {
        if (process.env.PROXY_URL && process.env.USE_PROXY === 'true') {
          return `${process.env.PROXY_URL}/lab-03-writeup`
        }
        if (process.env.USE_PROXY === 'true') {
          return `http://${proxyConfig.host}:${proxyConfig.port}/lab-03-writeup`
        }
        return 'https://labs.stg.pcioasis.com/lab-03-writeup'
      })(),
    },
  },
  prd: {
    homeIndex: 'https://labs.pcioasis.com',
    mainApp: 'https://www.pcioasis.com',
    firebaseProjectId: 'ui-firebase-pcioasis-prd',
    lab1: {
      // Lab 1 uses combined deployment (nginx + C2 in same container)
      vulnerable: 'https://lab-01-basic-magecart-prd-mmwwcfi5za-uc.a.run.app',
      c2: 'https://lab-01-basic-magecart-prd-mmwwcfi5za-uc.a.run.app',
      writeup: 'https://labs.pcioasis.com/lab-01-writeup',
    },
    lab2: {
      // Lab 2 uses separate deployments for vulnerable site and C2 server
      vulnerable: 'https://lab-02-dom-skimming-prd-mmwwcfi5za-uc.a.run.app',
      c2: 'https://lab-02-dom-skimming-c2-prd-mmwwcfi5za-uc.a.run.app',
      writeup: 'https://labs.pcioasis.com/lab-02-writeup',
    },
    lab3: {
      // Lab 3 uses separate deployments for vulnerable site and C2 server
      vulnerable: 'https://lab-03-extension-hijacking-prd-mmwwcfi5za-uc.a.run.app',
      c2: 'https://lab-03-extension-hijacking-c2-prd-mmwwcfi5za-uc.a.run.app',
      writeup: 'https://labs.pcioasis.com/lab-03-writeup',
    },
  },
}

const currentEnv = environments[TEST_ENV]

if (!currentEnv) {
  throw new Error(`Invalid TEST_ENV: ${TEST_ENV}. Must be one of: ${Object.keys(environments).join(', ')}`)
}

// Helper to get C2 API endpoint (adjusts port for local, path for prd)
function getC2ApiEndpoint(labNumber) {
  const labKey = `lab${labNumber}`
  const c2Url = currentEnv[labKey]?.c2

  if (!c2Url) {
    throw new Error(`C2 URL not found for ${labKey}`)
  }

  return `${c2Url}/api/stolen`
}

// Helper to get C2 collect endpoint
function getC2CollectEndpoint(labNumber) {
  const labKey = `lab${labNumber}`
  const c2Url = currentEnv[labKey]?.c2

  if (!c2Url) {
    throw new Error(`C2 URL not found for ${labKey}`)
  }

  return `${c2Url}/collect`
}

console.log(`🧪 Test Environment: ${TEST_ENV}`)
if (process.env.USE_PROXY === 'true' && process.env.PROXY_URL) {
  console.log(`🔗 Using gcloud proxy: ${process.env.PROXY_URL}`)
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
