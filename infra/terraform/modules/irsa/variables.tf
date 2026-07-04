variable "name" {
  type        = string
  description = "IAM role name."
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace for the service account."
}

variable "service_account_name" {
  type        = string
  description = "Kubernetes service account name."
}

variable "oidc_provider_arn" {
  type        = string
  description = "EKS OIDC provider ARN."
}

variable "oidc_provider_url" {
  type        = string
  description = "EKS OIDC issuer URL."
}

variable "secret_arn" {
  type        = string
  description = "Secrets Manager secret ARN the workload can read."
}

variable "queue_arn" {
  type        = string
  description = "SQS queue ARN the workload can consume from."
}

variable "rds_iam_connect_arn" {
  type        = string
  description = "RDS IAM database auth ARN for the application DB user."
}
