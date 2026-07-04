output "endpoint" {
  value = aws_db_instance.this.endpoint
}

output "security_group_id" {
  value = aws_security_group.postgres.id
}

output "resource_id" {
  value = aws_db_instance.this.resource_id
}
