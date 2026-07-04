variable "name" {
  type        = string
  description = "Observability resource name prefix."
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch log retention."
  default     = 30
}

variable "enable_amp" {
  type        = bool
  description = "Whether to create an Amazon Managed Service for Prometheus workspace."
  default     = false
}
