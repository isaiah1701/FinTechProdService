variable "name" {
  type        = string
  description = "RDS identifier."
}

variable "vpc_id" {
  type        = string
  description = "VPC ID for the RDS security group."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for the DB subnet group."
}

variable "allowed_cidr_blocks" {
  type        = list(string)
  description = "CIDR blocks allowed to reach Postgres."
}

variable "engine_version" {
  type        = string
  description = "Postgres engine version."
  default     = "16.4"
}

variable "instance_class" {
  type        = string
  description = "RDS instance class."
  default     = "db.t4g.micro"
}

variable "database_name" {
  type        = string
  description = "Application database name."
  default     = "bank_accounts"
}

variable "master_username" {
  type        = string
  description = "Owner username. Runtime app uses a separate least-privilege role."
  default     = "bank_owner"
}

variable "allocated_storage" {
  type        = number
  description = "Initial storage in GiB."
  default     = 20
}

variable "max_allocated_storage" {
  type        = number
  description = "Autoscaling storage ceiling in GiB."
  default     = 100
}

variable "backup_retention_days" {
  type        = number
  description = "RDS automated backup retention."
  default     = 7
}

variable "iam_database_authentication_enabled" {
  type        = bool
  description = "Enable AWS IAM database authentication for production workloads."
  default     = true
}
