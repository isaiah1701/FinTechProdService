resource "aws_cloudwatch_log_group" "app" {
  name              = "/aws/eks/${var.name}"
  retention_in_days = var.log_retention_days
}

resource "aws_prometheus_workspace" "this" {
  count = var.enable_amp ? 1 : 0
  alias = var.name
}
