output "database_secret_arns" {
  value = { for name, secret in aws_secretsmanager_secret.database : name => secret.arn }
}
output "database_endpoints" {
  value = { postgresql = aws_db_instance.postgresql.address, mongodb = local.mongodb_host }
}
output "mongodb_ca_pem" { value = tls_self_signed_cert.mongodb_ca.cert_pem }
output "database_security_group_id" {
  value = aws_security_group.database.id
}
