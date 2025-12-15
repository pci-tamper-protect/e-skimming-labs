variable "deploy_services" {
  description = "Whether to deploy Cloud Run services (set to false for initial infrastructure deployment)"
  type        = bool
  default     = false
}

# project_id is calculated from environment - no need to pass it

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "us-central1"
}

variable "firestore_location" {
  description = "The Firestore location"
  type        = string
  default     = "us-central1"
}

variable "domain" {
  description = "The domain for the labs home page"
  type        = string
  default     = "labs.pcioasis.com"
}

variable "labs_domain" {
  description = "The domain for individual labs"
  type        = string
  default     = "labs.pcioasis.com"
}

variable "main_domain" {
  description = "The main pcioasis.com domain for SEO integration"
  type        = string
  default     = "pcioasis.com"
}

variable "environment" {
  description = "Environment (prd, stg) - REQUIRED, no default"
  type        = string
}

variable "min_instances" {
  description = "Minimum number of Cloud Run instances"
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Maximum number of Cloud Run instances"
  type        = number
  default     = 10
}

variable "cpu_limit" {
  description = "CPU limit for Cloud Run services"
  type        = string
  default     = "1"
}

variable "memory_limit" {
  description = "Memory limit for Cloud Run services"
  type        = string
  default     = "512Mi"
}

variable "additional_allowed_users" {
  description = "Additional user emails to grant access to staging services (beyond groups)"
  type        = list(string)
  default     = []
}

# labs_project_id is calculated from environment - no need to pass it
