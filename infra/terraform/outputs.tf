output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "database_endpoint" {
  value = module.rds.endpoint
}

output "database_secret_arn" {
  value = module.secrets.secret_arn
}

output "queue_url" {
  value = module.sqs.queue_url
}

output "service_account_role_arn" {
  value = module.irsa.role_arn
}
