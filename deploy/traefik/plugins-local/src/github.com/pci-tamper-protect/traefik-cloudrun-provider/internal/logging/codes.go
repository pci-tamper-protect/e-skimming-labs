package logging

// Plugin lifecycle codes
const (
	// CreateConfig lifecycle
	CodeCreateConfigSuccess = "PLUGIN_001_SUCCESS"
	CodeCreateConfigError   = "PLUGIN_001_ERROR"

	// New() lifecycle
	CodeNewSuccess           = "PLUGIN_002_SUCCESS"
	CodeNewError             = "PLUGIN_002_ERROR"
	CodeNewConfigNil         = "PLUGIN_002_ERROR_CONFIG_NIL"
	CodeNewProjectIDMissing = "PLUGIN_002_ERROR_PROJECT_ID_MISSING"
	CodeNewProjectIDFound    = "PLUGIN_002_SUCCESS_PROJECT_ID"
	CodeNewCloudRunClientError = "PLUGIN_002_ERROR_CLOUD_RUN_CLIENT"

	// Init() lifecycle
	CodeInitSuccess = "PLUGIN_003_SUCCESS"
	CodeInitError   = "PLUGIN_003_ERROR"

	// Provide() lifecycle
	CodeProvideSuccess              = "PLUGIN_004_SUCCESS"
	CodeProvideError                = "PLUGIN_004_ERROR"
	CodeProvideInitialConfigSuccess = "PLUGIN_004_SUCCESS_INITIAL_CONFIG"
	CodeProvideInitialConfigError   = "PLUGIN_004_ERROR_INITIAL_CONFIG"
	CodeProvidePollLoopStarted     = "PLUGIN_004_SUCCESS_POLL_LOOP_STARTED"

	// Polling
	CodePollStarted     = "PLUGIN_005_SUCCESS_POLL_STARTED"
	CodePollSuccess     = "PLUGIN_005_SUCCESS_POLL_COMPLETE"
	CodePollError       = "PLUGIN_005_ERROR_POLL_FAILED"
	CodePollStopped     = "PLUGIN_005_INFO_POLL_STOPPED"

	// Service Discovery
	CodeServiceDiscoveryStarted     = "PLUGIN_006_INFO_DISCOVERY_STARTED"
	CodeServiceDiscoverySuccess     = "PLUGIN_006_SUCCESS_DISCOVERY_COMPLETE"
	CodeServiceDiscoveryError       = "PLUGIN_006_ERROR_DISCOVERY_FAILED"
	CodeServiceDiscoveryNoServices  = "PLUGIN_006_WARN_NO_SERVICES"
	CodeServiceProcessingStarted     = "PLUGIN_006_INFO_SERVICE_PROCESSING"
	CodeServiceProcessingSuccess    = "PLUGIN_006_SUCCESS_SERVICE_PROCESSED"
	CodeServiceProcessingError       = "PLUGIN_006_ERROR_SERVICE_PROCESSING"
	CodeServiceSkipped              = "PLUGIN_006_INFO_SERVICE_SKIPPED"

	// Router Configuration
	CodeRouterConfigured = "PLUGIN_007_SUCCESS_ROUTER_CONFIGURED"
	CodeRouterError      = "PLUGIN_007_ERROR_ROUTER_CONFIG"

	// Token Management
	CodeTokenFetchSuccess = "PLUGIN_008_SUCCESS_TOKEN_FETCHED"
	CodeTokenFetchError   = "PLUGIN_008_ERROR_TOKEN_FETCH_FAILED"
	CodeTokenInvalid      = "PLUGIN_008_ERROR_TOKEN_INVALID"

	// Configuration Generation
	CodeConfigGenerationStarted = "PLUGIN_009_INFO_CONFIG_GENERATION_STARTED"
	CodeConfigGenerationSuccess = "PLUGIN_009_SUCCESS_CONFIG_GENERATION_COMPLETE"
	CodeConfigGenerationError   = "PLUGIN_009_ERROR_CONFIG_GENERATION_FAILED"
	CodeConfigSentSuccess       = "PLUGIN_009_SUCCESS_CONFIG_SENT"
	CodeConfigSentError         = "PLUGIN_009_ERROR_CONFIG_SEND_FAILED"

	// Internal Provider
	CodeInternalProviderCreated = "PLUGIN_010_SUCCESS_INTERNAL_PROVIDER_CREATED"
	CodeInternalProviderError   = "PLUGIN_010_ERROR_INTERNAL_PROVIDER_FAILED"
	CodeInternalProviderStarted = "PLUGIN_010_SUCCESS_INTERNAL_PROVIDER_STARTED"
)

// GetCodeField returns a Field with the code for structured logging
func GetCodeField(code string) Field {
	return Field{Key: "code", Value: code}
}
