resource "aws_secretsmanager_secret" "secret-manager-database-credentials" {
  name                    = "fiap-secret-manager-database-credentials"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "database-credentials" {
  secret_id = aws_secretsmanager_secret.secret-manager-database-credentials.id

  secret_string = jsonencode({
    "ConnectionStrings__DefaultConnection" = "Host=${aws_db_instance.rds-postgresql-instance.address};Port=5432;Database=${aws_db_instance.rds-postgresql-instance.db_name};Username=${var.db_username};Password=${var.db_password}"
  })
}
