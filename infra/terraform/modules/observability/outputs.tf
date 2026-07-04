output "log_group_name" {
  value = aws_cloudwatch_log_group.app.name
}

output "amp_workspace_id" {
  value = var.enable_amp ? aws_prometheus_workspace.this[0].id : null
}
