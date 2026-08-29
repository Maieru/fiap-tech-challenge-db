output "database_credentials_secret_arn" {
  description = "ARN do secret utilizado pelas credenciais do banco de dados"
  value       = try(aws_secretsmanager_secret.secret-manager-database-credentials.arn, null)
}

output "database_security_group_id" {
  description = "Identificador do security group associado ao PostgreSQL"
  value       = aws_security_group.rds_postgresql.id
}
