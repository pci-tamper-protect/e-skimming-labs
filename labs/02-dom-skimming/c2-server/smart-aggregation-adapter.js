/**
 * SMART-AGGREGATION-ADAPTER.JS - Efficient Cloud Storage with Intelligent Aggregation
 *
 * Solves the "lots of tiny files" problem with:
 * - Time-based batch files (hourly/daily aggregation)
 * - Summary indexes for fast dashboard queries
 * - In-memory caching layer
 * - Streaming/pagination for large datasets
 */

const { Storage } = require('@google-cloud/storage')

class SmartAggregationAdapter {
  constructor(options = {}) {
    this.storage = new Storage({
      projectId: options.projectId || process.env.GOOGLE_CLOUD_PROJECT,
      keyFilename: options.keyFilename || process.env.GOOGLE_APPLICATION_CREDENTIALS
    })

    this.bucketName = options.bucketName || process.env.C2_STORAGE_BUCKET || 'e-skimming-labs-c2-data'
    this.bucket = this.storage.bucket(this.bucketName)

    this.labId = options.labId || process.env.LAB_ID || 'lab2-dom-skimming'
    this.instanceId = options.instanceId || process.env.INSTANCE_ID || this.generateInstanceId()

    // Batching strategy - time-based aggregation
    this.batchConfig = {
      // Write attacks to hourly batch files for better aggregation
      batchWindowMinutes: options.batchWindowMinutes || 60, // 1 hour batches
      maxBatchSize: options.maxBatchSize || 500, // Max attacks per batch
      maxBatchSizeBytes: options.maxBatchSizeBytes || 5 * 1024 * 1024 // 5MB max per batch
    }

    // In-memory caching to avoid repeated Cloud Storage calls
    this.cache = {
      summary: null,
      summaryExpiry: null,
      recentData: null,
      recentDataExpiry: null,
      ttlMinutes: options.cacheTtlMinutes || 5 // Cache for 5 minutes
    }

    this.pendingBatch = []
    this.currentBatchWindow = null
    this.batchTimer = null

    this.logger = options.logger || console
  }

  generateInstanceId() {
    const timestamp = Date.now().toString(36)
    const random = Math.random().toString(36).substring(2, 8)
    return `${timestamp}-${random}`
  }

  /**
   * Get current time-based batch window (e.g., "2026-03-07-14" for hour 14)
   */
  getCurrentBatchWindow(timestamp = Date.now()) {
    const date = new Date(timestamp)
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const day = String(date.getDate()).padStart(2, '0')
    const hour = String(date.getHours()).padStart(2, '0')

    if (this.batchConfig.batchWindowMinutes >= 60) {
      return `${year}-${month}-${day}-${hour}` // Hourly batches
    } else {
      const minute = Math.floor(date.getMinutes() / this.batchConfig.batchWindowMinutes) * this.batchConfig.batchWindowMinutes
      const minuteStr = String(minute).padStart(2, '0')
      return `${year}-${month}-${day}-${hour}-${minuteStr}` // Sub-hourly batches
    }
  }

  /**
   * Save attack data with intelligent batching
   */
  async saveAttackData(attackType, data) {
    const enrichedData = {
      ...data,
      serverTimestamp: Date.now(),
      serverTime: new Date().toISOString(),
      attackType,
      labId: this.labId,
      instanceId: this.instanceId
    }

    const batchWindow = this.getCurrentBatchWindow(enrichedData.serverTimestamp)

    // If batch window changed, flush previous batch immediately
    if (this.currentBatchWindow && this.currentBatchWindow !== batchWindow) {
      await this.flushBatch()
    }

    this.currentBatchWindow = batchWindow
    this.pendingBatch.push(enrichedData)

    // Check if we should flush the batch
    const shouldFlush =
      this.pendingBatch.length >= this.batchConfig.maxBatchSize ||
      this.calculateBatchSize() >= this.batchConfig.maxBatchSizeBytes

    if (shouldFlush) {
      await this.flushBatch()
    } else if (!this.batchTimer) {
      // Set timer for automatic flush (shorter than batch window)
      const flushInterval = Math.min(this.batchConfig.batchWindowMinutes * 60 * 1000 / 4, 30000) // Max 30s
      this.batchTimer = setTimeout(() => this.flushBatch(), flushInterval)
    }

    // Invalidate cached data
    this.invalidateCache()

    return `gs://${this.bucketName}/${this.labId}/attacks/${batchWindow}/`
  }

  calculateBatchSize() {
    return JSON.stringify(this.pendingBatch).length
  }

  /**
   * Flush pending batch with smart file naming
   */
  async flushBatch() {
    if (this.pendingBatch.length === 0) return

    try {
      const timestamp = Date.now()
      const batchWindow = this.currentBatchWindow || this.getCurrentBatchWindow(timestamp)

      // Organize by time-based directories for efficient querying
      const fileName = `${this.labId}/attacks/${batchWindow}/batch_${timestamp}_${this.instanceId}.json`

      const batchData = {
        batchId: `${this.instanceId}_${timestamp}`,
        batchWindow: batchWindow,
        timestamp: timestamp,
        batchSize: this.pendingBatch.length,
        attacks: this.pendingBatch,
        // Pre-computed aggregations for faster queries
        summary: this.computeBatchSummary(this.pendingBatch)
      }

      const file = this.bucket.file(fileName)
      await file.save(JSON.stringify(batchData, null, 2), {
        metadata: {
          contentType: 'application/json',
          metadata: {
            labId: this.labId,
            instanceId: this.instanceId,
            batchWindow: batchWindow,
            batchSize: this.pendingBatch.length.toString(),
            attackTypes: [...new Set(this.pendingBatch.map(a => a.attackType))].join(','),
            hasCardData: this.pendingBatch.some(a => this.hasCardData(a)) ? 'true' : 'false'
          }
        }
      })

      // Also update summary index for fast dashboard queries
      await this.updateSummaryIndex(batchData)

      this.logger.log(`[SmartAggregation] Flushed batch: ${this.pendingBatch.length} attacks to window ${batchWindow}`)

      // Clear batch and timer
      this.pendingBatch = []
      this.currentBatchWindow = null
      if (this.batchTimer) {
        clearTimeout(this.batchTimer)
        this.batchTimer = null
      }

    } catch (error) {
      this.logger.error('[SmartAggregation] Batch flush failed:', error.message)
    }
  }

  /**
   * Compute batch-level summary for aggregation
   */
  computeBatchSummary(attacks) {
    const cardAttacks = attacks.filter(a => this.hasCardData(a))
    const formSubmissions = attacks.filter(a => a.type === 'form_submission')

    return {
      totalAttacks: attacks.length,
      cardDataCount: cardAttacks.length,
      formSubmissionCount: formSubmissions.length,
      attackTypes: [...new Set(attacks.map(a => a.attackType || a.type))],
      timeRange: {
        start: Math.min(...attacks.map(a => a.serverTimestamp || a.timestamp)),
        end: Math.max(...attacks.map(a => a.serverTimestamp || a.timestamp))
      },
      uniqueVictims: [...new Set(attacks.map(a => a.metadata?.userAgent || 'unknown'))].length
    }
  }

  /**
   * Check if attack contains credit card data
   */
  hasCardData(attack) {
    // Check different attack formats for card data
    if (attack.type === 'form_submission' && attack.formData) {
      return Object.values(attack.formData).some(field =>
        field.fieldType === 'text' &&
        (field.fieldName?.includes('card') || field.autocomplete?.includes('cc-'))
      )
    }

    // Legacy format checks
    if (attack.fullData?.fieldValues) {
      return Object.values(attack.fullData.fieldValues).some(field =>
        field.fieldName?.includes('card') || field.autocomplete?.includes('cc-')
      )
    }

    return false
  }

  /**
   * Update summary index for fast dashboard queries
   */
  async updateSummaryIndex(batchData) {
    try {
      const indexPath = `${this.labId}/index/daily-summary.json`
      const today = new Date().toISOString().split('T')[0] // YYYY-MM-DD

      let existingSummary = {}
      try {
        const [content] = await this.bucket.file(indexPath).download()
        existingSummary = JSON.parse(content.toString())
      } catch (e) {
        // File doesn't exist yet, start fresh
      }

      // Update today's summary
      if (!existingSummary[today]) {
        existingSummary[today] = {
          totalAttacks: 0,
          cardDataCount: 0,
          formSubmissionCount: 0,
          uniqueVictims: new Set(),
          batchWindows: []
        }
      }

      const todaySummary = existingSummary[today]
      todaySummary.totalAttacks += batchData.summary.totalAttacks
      todaySummary.cardDataCount += batchData.summary.cardDataCount
      todaySummary.formSubmissionCount += batchData.summary.formSubmissionCount
      todaySummary.batchWindows.push(batchData.batchWindow)

      // Handle Set serialization
      const victimsArray = Array.from(todaySummary.uniqueVictims || [])
      batchData.attacks.forEach(a => {
        const victim = a.metadata?.userAgent || 'unknown'
        if (!victimsArray.includes(victim)) {
          victimsArray.push(victim)
        }
      })
      todaySummary.uniqueVictims = victimsArray
      todaySummary.uniqueVictimsCount = victimsArray.length

      // Save updated summary
      await this.bucket.file(indexPath).save(JSON.stringify(existingSummary, null, 2))

    } catch (error) {
      this.logger.warn('[SmartAggregation] Failed to update summary index:', error.message)
    }
  }

  /**
   * Get recent attacks with intelligent caching and aggregation
   */
  async getRecentAttacks(limit = 100) {
    // Check cache first
    if (this.cache.recentData && this.cache.recentDataExpiry > Date.now()) {
      this.logger.log('[SmartAggregation] Returning cached recent attacks')
      return this.cache.recentData.slice(0, limit)
    }

    try {
      this.logger.log('[SmartAggregation] Fetching recent attacks from Cloud Storage...')

      // Get recent batch windows (last 24 hours)
      const recentWindows = this.getRecentBatchWindows(24)
      const allAttacks = []

      // Process batch windows in parallel (limited concurrency)
      const batchPromises = recentWindows.slice(0, 50).map(async (window) => {
        try {
          const [files] = await this.bucket.getFiles({
            prefix: `${this.labId}/attacks/${window}/`,
            maxResults: 20 // Limit files per window
          })

          const windowAttacks = []
          for (const file of files) {
            try {
              const [content] = await file.download()
              const batchData = JSON.parse(content.toString())

              if (batchData.attacks && Array.isArray(batchData.attacks)) {
                windowAttacks.push(...batchData.attacks)
              }
            } catch (parseError) {
              this.logger.warn(`[SmartAggregation] Failed to parse batch file ${file.name}`)
            }
          }

          return windowAttacks
        } catch (error) {
          this.logger.warn(`[SmartAggregation] Failed to process window ${window}:`, error.message)
          return []
        }
      })

      const windowResults = await Promise.all(batchPromises)
      windowResults.forEach(attacks => allAttacks.push(...attacks))

      // Sort by timestamp and limit
      const sortedAttacks = allAttacks
        .sort((a, b) => (b.serverTimestamp || b.timestamp) - (a.serverTimestamp || a.timestamp))
        .slice(0, Math.max(limit, 500)) // Cache more for future requests

      // Update cache
      this.cache.recentData = sortedAttacks
      this.cache.recentDataExpiry = Date.now() + (this.cache.ttlMinutes * 60 * 1000)

      this.logger.log(`[SmartAggregation] Loaded ${sortedAttacks.length} attacks from ${windowResults.length} windows`)

      return sortedAttacks.slice(0, limit)

    } catch (error) {
      this.logger.error('[SmartAggregation] Failed to get recent attacks:', error.message)
      return []
    }
  }

  /**
   * Generate list of recent batch windows
   */
  getRecentBatchWindows(hours = 24) {
    const windows = []
    const now = Date.now()
    const windowMs = this.batchConfig.batchWindowMinutes * 60 * 1000

    for (let i = 0; i < hours * (60 / this.batchConfig.batchWindowMinutes); i++) {
      const windowStart = now - (i * windowMs)
      windows.push(this.getCurrentBatchWindow(windowStart))
    }

    return [...new Set(windows)] // Remove duplicates
  }

  /**
   * Get aggregated statistics (fast dashboard summary)
   */
  async getStatsSummary() {
    // Check cache first
    if (this.cache.summary && this.cache.summaryExpiry > Date.now()) {
      return this.cache.summary
    }

    try {
      // Try to load from daily summary index first (much faster)
      const indexPath = `${this.labId}/index/daily-summary.json`
      const [content] = await this.bucket.file(indexPath).download()
      const dailySummary = JSON.parse(content.toString())

      // Aggregate last 7 days
      const last7Days = Object.keys(dailySummary)
        .sort()
        .slice(-7)

      const stats = {
        totalAttacks: 0,
        cardDataCount: 0,
        formSubmissionCount: 0,
        uniqueVictims: 0,
        activeDays: last7Days.length,
        lastUpdate: Date.now()
      }

      const allVictims = new Set()
      last7Days.forEach(day => {
        const dayData = dailySummary[day]
        stats.totalAttacks += dayData.totalAttacks || 0
        stats.cardDataCount += dayData.cardDataCount || 0
        stats.formSubmissionCount += dayData.formSubmissionCount || 0

        if (dayData.uniqueVictims) {
          dayData.uniqueVictims.forEach(v => allVictims.add(v))
        }
      })

      stats.uniqueVictims = allVictims.size

      // Update cache
      this.cache.summary = stats
      this.cache.summaryExpiry = Date.now() + (this.cache.ttlMinutes * 60 * 1000)

      return stats

    } catch (error) {
      this.logger.warn('[SmartAggregation] Failed to load summary, falling back to recent data:', error.message)

      // Fallback: compute from recent attacks
      const recentAttacks = await this.getRecentAttacks(1000)
      const uniqueVictims = new Set(recentAttacks.map(a => a.metadata?.userAgent || 'unknown'))

      return {
        totalAttacks: recentAttacks.length,
        cardDataCount: recentAttacks.filter(a => this.hasCardData(a)).length,
        formSubmissionCount: recentAttacks.filter(a => a.type === 'form_submission').length,
        uniqueVictims: uniqueVictims.size,
        lastUpdate: Date.now()
      }
    }
  }

  /**
   * Invalidate cached data
   */
  invalidateCache() {
    this.cache.summary = null
    this.cache.summaryExpiry = null
    this.cache.recentData = null
    this.cache.recentDataExpiry = null
  }

  /**
   * Health check with cache status
   */
  async healthCheck() {
    try {
      await this.bucket.exists()
      return {
        status: 'healthy',
        storage: 'connected',
        cache: {
          summary: this.cache.summary ? 'cached' : 'empty',
          recentData: this.cache.recentData ? `${this.cache.recentData.length} items` : 'empty'
        }
      }
    } catch (error) {
      return { status: 'unhealthy', error: error.message }
    }
  }

  /**
   * Cleanup with cache flush
   */
  async cleanup() {
    if (this.pendingBatch.length > 0) {
      await this.flushBatch()
    }
    if (this.batchTimer) {
      clearTimeout(this.batchTimer)
    }
    this.invalidateCache()
  }
}

module.exports = SmartAggregationAdapter
