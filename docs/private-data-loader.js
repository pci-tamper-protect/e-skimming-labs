/**
 * Private Data Plugin Loader for E-Skimming Labs
 *
 * This module allows licensed users to load private attack data
 * from private-e-skimming-attacks repository to enhance the
 * public MITRE ATT&CK matrix and threat model.
 *
 * Architecture:
 *   - Public repos = Framework + Display Logic (source of truth)
 *   - Private repos = Data Plugins (YAML/JSON attack definitions)
 *
 * Usage:
 *   <script src="private-data-loader.js"></script>
 *   <script>
 *     PrivateDataLoader.init({
 *       licenseKey: 'YOUR_LICENSE_KEY',
 *       privateRepoUrl: 'https://api.private-attacks.pcioasis.com'
 *     });
 *   </script>
 */

;(function (window) {
  'use strict'

  const PrivateDataLoader = {
    config: {
      licenseKey: null,
      privateRepoUrl: null,
      localMode: false,
      localDataPath: '../private-data' // Symlink to private repo
    },

    state: {
      initialized: false,
      licenseValid: false,
      privateAttacks: [],
      privateThreatNodes: [],
      privateThreatLinks: [],
      privateScenarios: {}
    },

    /**
     * Initialize the private data loader
     */
    init: async function (options) {
      console.log('[Private Data Loader] Initializing...')

      this.config = { ...this.config, ...options }

      // Validate license
      if (!this.config.localMode) {
        const valid = await this.validateLicense()
        if (!valid) {
          console.warn('[Private Data Loader] Invalid license key')
          return false
        }
      }

      // Load private data
      await this.loadPrivateAttacks()
      await this.loadPrivateThreatModel()

      this.state.initialized = true
      console.log('[Private Data Loader] Initialization complete')
      console.log(
        `[Private Data Loader] Loaded ${this.state.privateAttacks.length} private attacks`
      )

      // Dispatch event for other components
      window.dispatchEvent(
        new CustomEvent('privateDataLoaded', {
          detail: {
            attacks: this.state.privateAttacks,
            threatNodes: this.state.privateThreatNodes,
            threatLinks: this.state.privateThreatLinks
          }
        })
      )

      return true
    },

    /**
     * Validate license key with API
     */
    validateLicense: async function () {
      if (this.config.localMode) {
        return true // Skip validation in local mode
      }

      try {
        const response = await fetch(`${this.config.privateRepoUrl}/validate`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${this.config.licenseKey}`
          }
        })

        if (response.ok) {
          const data = await response.json()
          this.state.licenseValid = data.valid
          this.state.tier = data.tier
          return data.valid
        }
        return false
      } catch (error) {
        console.error('[Private Data Loader] License validation failed:', error)
        return false
      }
    },

    /**
     * Load private attacks from repository
     */
    loadPrivateAttacks: async function () {
      try {
        let attacks

        if (this.config.localMode) {
          // Local development mode - load from file system
          attacks = await this.loadLocalAttacks()
        } else {
          // Production mode - load from API
          const response = await fetch(`${this.config.privateRepoUrl}/attacks`, {
            headers: {
              Authorization: `Bearer ${this.config.licenseKey}`
            }
          })
          attacks = await response.json()
        }

        this.state.privateAttacks = attacks
        return attacks
      } catch (error) {
        console.error('[Private Data Loader] Failed to load private attacks:', error)
        return []
      }
    },

    /**
     * Load local attacks (development mode)
     */
    loadLocalAttacks: async function () {
      // In local mode, load from JSON index file via symlink
      try {
        const response = await fetch('../private-data/attacks-index.json')
        if (!response.ok) {
          console.warn('[Private Data Loader] Could not load attacks-index.json')
          return []
        }
        const data = await response.json()
        return data.attacks || []
      } catch (error) {
        console.warn('[Private Data Loader] Error loading local attacks:', error)
        return []
      }
    },

    /**
     * Load private threat model data
     */
    loadPrivateThreatModel: async function () {
      try {
        let threatModelData

        if (this.config.localMode) {
          threatModelData = await this.loadLocalThreatModel()
        } else {
          const response = await fetch(`${this.config.privateRepoUrl}/threat-model`, {
            headers: {
              Authorization: `Bearer ${this.config.licenseKey}`
            }
          })
          threatModelData = await response.json()
        }

        this.state.privateThreatNodes = threatModelData.nodes || []
        this.state.privateThreatLinks = threatModelData.links || []
        this.state.privateScenarios = threatModelData.scenarios || {}

        return threatModelData
      } catch (error) {
        console.error('[Private Data Loader] Failed to load threat model data:', error)
        return { nodes: [], links: [], scenarios: {} }
      }
    },

    /**
     * Load local threat model (development mode)
     */
    loadLocalThreatModel: async function () {
      // In local mode, load from JSON threat model file via symlink
      try {
        const response = await fetch('../private-data/threat-model-data.json')
        if (!response.ok) {
          console.warn('[Private Data Loader] Could not load threat-model-data.json')
          return { nodes: [], links: [], scenarios: {} }
        }
        const data = await response.json()
        return {
          nodes: data.nodes || [],
          links: data.links || [],
          scenarios: data.scenarios || {}
        }
      } catch (error) {
        console.warn('[Private Data Loader] Error loading local threat model:', error)
        return { nodes: [], links: [], scenarios: {} }
      }
    },

    /**
     * Get all private attacks
     */
    getPrivateAttacks: function () {
      return this.state.privateAttacks
    },

    /**
     * Get private threat model nodes
     */
    getPrivateThreatNodes: function () {
      return this.state.privateThreatNodes
    },

    /**
     * Get private threat model links
     */
    getPrivateThreatLinks: function () {
      return this.state.privateThreatLinks
    },

    /**
     * Get private scenarios
     */
    getPrivateScenarios: function () {
      return this.state.privateScenarios
    },

    /**
     * Check if private data is loaded
     */
    isLoaded: function () {
      return this.state.initialized
    },

    /**
     * Get license tier
     */
    getLicenseTier: function () {
      return this.state.tier || 'none'
    },

    /**
     * Merge private attacks into public MITRE matrix
     * This function is called by mitre-attack-visual.html
     */
    enrichMitreMatrix: function (publicTechniques) {
      if (!this.state.initialized) {
        return publicTechniques
      }

      const enriched = { ...publicTechniques }

      this.state.privateAttacks.forEach(attack => {
        attack.mitreTechniques.forEach(technique => {
          const tacticId = this.getTacticForTechnique(technique.id)
          if (!enriched[tacticId]) {
            enriched[tacticId] = []
          }

          enriched[tacticId].push({
            id: technique.id,
            name: technique.name,
            status: attack.status,
            visibility: 'private',
            attackId: attack.id,
            description: technique.description || attack.description
          })
        })
      })

      return enriched
    },

    /**
     * Helper: Get tactic ID for a technique
     */
    getTacticForTechnique: function (techniqueId) {
      // Simplified mapping - in real implementation, use MITRE ATT&CK API
      const mapping = {
        T1195: 'TA0001', // Initial Access
        T1059: 'TA0002', // Execution
        T1027: 'TA0005', // Defense Evasion
        T1056: 'TA0009', // Collection
        T1041: 'TA0010', // Exfiltration
        'CUSTOM-WASM-001': 'TA0002' // Execution
      }

      const baseId = techniqueId.split('.')[0]
      return mapping[baseId] || 'TA0001'
    }
  }

  // Export to window
  window.PrivateDataLoader = PrivateDataLoader

  // Auto-initialize if config is present
  if (window.PRIVATE_DATA_CONFIG) {
    PrivateDataLoader.init(window.PRIVATE_DATA_CONFIG)
  }
})(window)
