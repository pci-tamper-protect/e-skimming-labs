#!/usr/bin/env node
/**
 * Run Lighthouse with mobile form factor against the home index.
 *
 * Env:
 *   BASE_URL          - origin (default http://localhost:8080), same as test/config/test-env.js
 *   LIGHTHOUSE_PATH   - path to audit (default /)
 *   LIGHTHOUSE_OUTPUT - output basename (default lighthouse-reports/mobile)
 */
const { spawnSync } = require('child_process')
const fs = require('fs')
const path = require('path')

const baseUrl = (process.env.BASE_URL || 'http://localhost:8080').replace(/\/$/, '')
const auditPath = process.env.LIGHTHOUSE_PATH || '/'
const targetUrl = new URL(auditPath, `${baseUrl}/`).href

const reportBasename =
  process.env.LIGHTHOUSE_OUTPUT ||
  path.join(__dirname, '..', 'lighthouse-reports', 'mobile')

const reportDir = path.dirname(reportBasename)
fs.mkdirSync(reportDir, { recursive: true })

const lighthouseCli = path.join(__dirname, '..', 'node_modules', 'lighthouse', 'cli', 'index.js')

const args = [
  lighthouseCli,
  targetUrl,
  '--form-factor=mobile',
  '--screenEmulation.mobile',
  '--chrome-flags=--headless=new --no-sandbox --disable-dev-shm-usage',
  '--output=html,json',
  `--output-path=${reportBasename}`,
  '--only-categories=performance,accessibility,best-practices,seo',
  '--quiet',
]

console.log(`Lighthouse mobile audit: ${targetUrl}`)
console.log(`Reports: ${reportBasename}.report.html, ${reportBasename}.report.json`)

const result = spawnSync(process.execPath, args, { stdio: 'inherit' })
process.exit(result.status === null ? 1 : result.status)
