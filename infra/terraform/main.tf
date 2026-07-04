module "ecr" {
  source = "./modules/ecr"

  name = var.name_prefix
}

module "eks" {
  source = "./modules/eks"

  name             = "bank-platform"
  cluster_version  = var.eks_cluster_version
  subnet_ids       = var.private_subnet_ids
  cluster_role_arn = var.eks_cluster_role_arn
  node_role_arn    = var.eks_node_role_arn
}

module "rds" {
  source = "./modules/rds"

  name                = var.name_prefix
  vpc_id              = var.vpc_id
  subnet_ids          = var.private_subnet_ids
  allowed_cidr_blocks = var.db_allowed_cidr_blocks
}

module "secrets" {
  source = "./modules/secrets"

  name        = "bank/prod/account-service/database"
  description = "Database connection details for ${var.name_prefix}. Value is inserted out-of-band."
}

module "sqs" {
  source = "./modules/sqs"

  name = "${var.name_prefix}-events"
}

module "irsa" {
  source = "./modules/irsa"

  name                 = var.name_prefix
  namespace            = "default"
  service_account_name = "bank-account-service"
  oidc_provider_arn    = var.eks_oidc_provider_arn
  oidc_provider_url    = var.eks_oidc_provider_url
  secret_arn           = module.secrets.secret_arn
  queue_arn            = module.sqs.queue_arn
  rds_iam_connect_arn  = "arn:aws:rds-db:${var.aws_region}:${var.aws_account_id}:dbuser:${module.rds.resource_id}/bank_account_app"
}

module "observability" {
  source = "./modules/observability"

  name       = var.name_prefix
  enable_amp = false
}
