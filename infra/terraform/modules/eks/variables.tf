variable "name" {
  type        = string
  description = "EKS cluster name."
}

variable "cluster_version" {
  type        = string
  description = "EKS cluster version."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets for the EKS cluster and managed node group."
}

variable "cluster_role_arn" {
  type        = string
  description = "IAM role ARN for EKS control plane."
}

variable "node_role_arn" {
  type        = string
  description = "IAM role ARN for EKS nodes."
}

variable "node_instance_types" {
  type        = list(string)
  description = "Managed node group instance types."
  default     = ["t3.medium"]
}
