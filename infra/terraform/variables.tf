variable "aws_region" {
  type        = string
  description = "AWS region for production-shaped resources."
  default     = "eu-west-2"
}

variable "aws_account_id" {
  type        = string
  description = "AWS account ID used only to shape IAM database auth ARNs. Example value is a placeholder."
  default     = "000000000000"
}

variable "environment" {
  type        = string
  description = "Deployment environment name."
  default     = "prod"
}

variable "name_prefix" {
  type        = string
  description = "Shared name prefix for bank account service resources."
  default     = "bank-account-service"
}

variable "vpc_id" {
  type        = string
  description = "Existing VPC ID. Placeholder values are enough for validation."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Existing private subnet IDs. Placeholder values are enough for validation."
}

variable "db_allowed_cidr_blocks" {
  type        = list(string)
  description = "CIDR blocks allowed to reach RDS Postgres."
  default     = ["10.0.0.0/16"]
}

variable "eks_cluster_version" {
  type        = string
  description = "EKS cluster version."
  default     = "1.31"
}

variable "eks_cluster_role_arn" {
  type        = string
  description = "IAM role ARN used by the EKS cluster."
}

variable "eks_node_role_arn" {
  type        = string
  description = "IAM role ARN used by the EKS managed node group."
}

variable "eks_oidc_provider_arn" {
  type        = string
  description = "EKS OIDC provider ARN used for IRSA."
}

variable "eks_oidc_provider_url" {
  type        = string
  description = "EKS OIDC issuer URL used for IRSA trust conditions."
}
