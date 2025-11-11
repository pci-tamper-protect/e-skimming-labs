/**
 * Test Environment Configuration
 *
 * This module provides environment-aware URLs for running tests against different deployments:
 * - local: Docker Compose on localhost
 * - prd: Production deployment at labs.pcioasis.com
 *
 * Usage:
 *   Set TEST_ENV environment variable: TEST_ENV=prd npm test
 *   Defaults to 'local' if not set
 */

const TEST_ENV = process.env.TEST_ENV || 'local'

const environments = {
  local: {
    homeIndex: 'http://localhost:3000',
    lab1: {
      vulnerable: 'http://localhost:9001',
      c2: 'http://localhost:9002',
    },
    lab2: {
      vulnerable: 'http://localhost:9003',
      c2: 'http://localhost:9004',
    },
    lab3: {
      vulnerable: 'http://localhost:9005',
      c2: 'http://localhost:9006',
    },
  },
  prd: {
    homeIndex: 'https://labs.pcioasis.com',
    lab1: {
      // Production uses Cloud Run endpoints
      vulnerable: 'https://lab-01-basic-magecart-prd-mmwwcfi5za-uc.a.run.app',
      c2: 'https://lab-01-basic-magecart-c2-prd-mmwwcfi5za-uc.a.run.app',
    },
    lab2: {
      vulnerable: 'https://lab-02-dom-skimming-prd-mmwwcfi5za-uc.a.run.app',
      c2: 'https://lab-02-dom-skimming-c2-prd-mmwwcfi5za-uc.a.run.app',
    },
    lab3: {
      vulnerable: 'https://lab-03-extension-hijacking-prd-mmwwcfi5za-uc.a.run.app',
      c2: 'https://lab-03-extension-hijacking-c2-prd-mmwwcfi5za-uc.a.run.app',
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
console.log(`📍 Home Index: ${currentEnv.homeIndex}`)
console.log(`📍 Lab 1 Vulnerable: ${currentEnv.lab1.vulnerable}`)
console.log(`📍 Lab 1 C2: ${currentEnv.lab1.c2}`)

module.exports = {
  TEST_ENV,
  environments,
  currentEnv,
  getC2ApiEndpoint,
  getC2CollectEndpoint,
}
