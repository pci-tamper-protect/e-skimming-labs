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

const environments = {
  local: {
    homeIndex: 'http://localhost:3000',
    mainApp: 'http://localhost:5173',
    lab1: {
      vulnerable: 'http://localhost:9001',
      c2: 'http://localhost:9002',
      writeup: 'http://localhost:3000/lab-01-writeup',
    },
    lab2: {
      vulnerable: 'http://localhost:9003',
      c2: 'http://localhost:9004',
      writeup: 'http://localhost:3000/lab-02-writeup',
    },
    lab3: {
      vulnerable: 'http://localhost:9005',
      c2: 'http://localhost:9006',
      writeup: 'http://localhost:3000/lab-03-writeup',
    },
  },
  stg: {
    homeIndex: 'https://labs.stg.pcioasis.com',
    mainApp: 'https://stg.pcioasis.com',
    firebaseProjectId: 'ui-firebase-pcioasis-stg',
    lab1: {
      vulnerable: 'https://lab-01-basic-magecart-stg-mmwwcfi5za-uc.a.run.app',
      c2: 'https://lab-01-basic-magecart-stg-mmwwcfi5za-uc.a.run.app',
      writeup: 'https://labs.stg.pcioasis.com/lab-01-writeup',
    },
    lab2: {
      vulnerable: 'https://lab-02-dom-skimming-stg-mmwwcfi5za-uc.a.run.app',
      c2: 'https://lab-02-dom-skimming-c2-stg-mmwwcfi5za-uc.a.run.app',
      writeup: 'https://labs.stg.pcioasis.com/lab-02-writeup',
    },
    lab3: {
      vulnerable: 'https://lab-03-extension-hijacking-stg-mmwwcfi5za-uc.a.run.app',
      c2: 'https://lab-03-extension-hijacking-c2-stg-mmwwcfi5za-uc.a.run.app',
      writeup: 'https://labs.stg.pcioasis.com/lab-03-writeup',
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
