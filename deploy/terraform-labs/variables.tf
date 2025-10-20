variable "deploy_services" {
  description = "Whether to deploy Cloud Run services (set to false for initial infrastructure deployment)"
  type        = bool
  default     = false
}

variable "project_id" {
  description = "The GCP project ID for individual labs"
  type        = string
  default     = "labs-prd"
}

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
  description = "The domain for individual labs"
  type        = string
  default     = "labs.pcioasis.com"
}

variable "home_domain" {
  description = "The domain for the home page"
  type        = string
  default     = "labs.pcioasis.com"
}

variable "main_domain" {
  description = "The main pcioasis.com domain for SEO integration"
  type        = string
  default     = "pcioasis.com"
}

variable "environment" {
  description = "Environment (prd, stg)"
  type        = string
  default     = "prd"
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
