/**
 * CLOUD-STORAGE-ADAPTER.JS - Cloud Storage Data Persistence for C2 Server
 *
 * Replaces local file storage with Cloud Storage for Cloud Run deployments
 * Optimized for low cost, acceptable latency, no consistency requirements
 */

const { Storage } = require('@google-cloud/storage')
const path = require('path')

class CloudStorageAdapter {
  constructor(options = {}) {
    this.storage = new Storage({
      projectId: options.projectId || process.env.GOOGLE_CLOUD_PROJECT,
      keyFilename: options.keyFilename || process.env.GOOGLE_APPLICATION_CREDENTIALS
    })

    this.bucketName = options.bucketName || process.env.C2_STORAGE_BUCKET || 'e-skimming-labs-c2-data'
    this.bucket = this.storage.bucket(this.bucketName)

    // Lab identification for multi-tenant storage
    this.labId = options.labId || process.env.LAB_ID || 'lab2-dom-skimming'
    this.instanceId = options.instanceId || process.env.INSTANCE_ID || this.generateInstanceId()

    // Batching configuration for cost optimization
    this.batchConfig = {
      maxBatchSize: options.maxBatchSize || 100, // Max items per batch
      maxBatchWait: options.maxBatchWait || 5000, // Max wait time in ms
      maxBatchSizeBytes: options.maxBatchSizeBytes || 1024 * 1024 // 1MB max per batch
    }

    this.pendingBatch = []
    this.batchTimer = null

    this.logger = options.logger || console
  }

  generateInstanceId() {
    const timestamp = Date.now().toString(36)
    const random = Math.random().toString(36).substring(2, 8)
    return `${timestamp}-${random}`
  }

  /**
   * Save attack data (replaces fs.writeFileSync)
   * Uses batching for cost optimization
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

    // Add to batch
    this.pendingBatch.push(enrichedData)

    // Check if we should flush the batch
    const shouldFlush =
      this.pendingBatch.length >= this.batchConfig.maxBatchSize ||
      this.calculateBatchSize() >= this.batchConfig.maxBatchSizeBytes

    if (shouldFlush) {
      await this.flushBatch()
    } else if (!this.batchTimer) {
      // Set timer for automatic flush
      this.batchTimer = setTimeout(() => this.flushBatch(), this.batchConfig.maxBatchWait)
    }

    return `gs://${this.bucketName}/${this.labId}/attacks/batch_${Date.now()}.json`
  }

  calculateBatchSize() {
    return JSON.stringify(this.pendingBatch).length
  }

  /**
   * Flush pending batch to Cloud Storage
   */
  async flushBatch() {
    if (this.pendingBatch.length === 0) return

    try {
      const timestamp = Date.now()
      const fileName = `${this.labId}/attacks/batch_${timestamp}_${this.instanceId}.json`

      const batchData = {
        batchId: `${this.instanceId}_${timestamp}`,
        timestamp: timestamp,
        batchSize: this.pendingBatch.length,
        attacks: this.pendingBatch
      }

      const file = this.bucket.file(fileName)
      await file.save(JSON.stringify(batchData, null, 2), {
        metadata: {
          contentType: 'application/json',
          metadata: {
            labId: this.labId,
            instanceId: this.instanceId,
            batchSize: this.pendingBatch.length.toString(),
            attackTypes: [...new Set(this.pendingBatch.map(a => a.attackType))].join(',')
          }
        }
      })

      this.logger.log(`[CloudStorage] Flushed batch: ${this.pendingBatch.length} attacks to ${fileName}`)

      // Clear batch and timer
      this.pendingBatch = []
      if (this.batchTimer) {
        clearTimeout(this.batchTimer)
        this.batchTimer = null
      }

    } catch (error) {
      this.logger.error('[CloudStorage] Batch flush failed:', error.message)
      // Could implement retry logic here
    }
  }

  /**
   * Get recent attack data (replaces reading stolen.json)
   */
  async getRecentAttacks(limit = 100) {
    try {
      const [files] = await this.bucket.getFiles({
        prefix: `${this.labId}/attacks/`,
        maxResults: 50, // Get recent batch files
        orderBy: 'timeCreated',
        descending: true
      })

      const allAttacks = []

      for (const file of files) {
        if (allAttacks.length >= limit) break

        try {
          const [content] = await file.download()
          const batchData = JSON.parse(content.toString())

          if (batchData.attacks && Array.isArray(batchData.attacks)) {
            allAttacks.push(...batchData.attacks)
          }
        } catch (parseError) {
          this.logger.warn(`[CloudStorage] Failed to parse batch file ${file.name}:`, parseError.message)
        }
      }

      // Sort by timestamp and limit
      return allAttacks
        .sort((a, b) => b.serverTimestamp - a.serverTimestamp)
        .slice(0, limit)

    } catch (error) {
      this.logger.error('[CloudStorage] Failed to get recent attacks:', error.message)
      return []
    }
  }

  /**
   * Save analysis data
   */
  async saveAnalysis(analysis) {
    try {
      const timestamp = Date.now()
      const fileName = `${this.labId}/analysis/analysis_${timestamp}_${this.instanceId}.json`

      const analysisData = {
        ...analysis,
        labId: this.labId,
        instanceId: this.instanceId,
        savedAt: timestamp
      }

      const file = this.bucket.file(fileName)
      await file.save(JSON.stringify(analysisData, null, 2), {
        metadata: {
          contentType: 'application/json',
          metadata: {
            labId: this.labId,
            attackType: analysis.attackType || 'unknown',
            severity: analysis.severity || 'unknown'
          }
        }
      })

      return fileName

    } catch (error) {
      this.logger.error('[CloudStorage] Failed to save analysis:', error.message)
      throw error
    }
  }

  /**
   * Health check - verify bucket access
   */
  async healthCheck() {
    try {
      await this.bucket.exists()
      return { status: 'healthy', storage: 'connected' }
    } catch (error) {
      return { status: 'unhealthy', error: error.message }
    }
  }

  /**
   * Cleanup - flush any pending data
   */
  async cleanup() {
    if (this.pendingBatch.length > 0) {
      await this.flushBatch()
    }
    if (this.batchTimer) {
      clearTimeout(this.batchTimer)
    }
  }
}

module.exports = CloudStorageAdapter
