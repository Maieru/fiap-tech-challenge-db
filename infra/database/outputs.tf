output "database_secret_arns" {
  value = { for name, secret in aws_secretsmanager_secret.database : name => secret.arn }
}
output "database_endpoints" {
  value = { postgresql = aws_db_instance.postgresql.address, documentdb = aws_docdb_cluster.execution.endpoint }
}
output "database_security_group_id" {
  value = aws_security_group.database.id
}
