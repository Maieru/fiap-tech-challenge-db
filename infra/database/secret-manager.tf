resource "random_password" "database" {
  for_each = toset(["postgres_admin", "documentdb_admin", "os", "billing", "execution"])
  length   = 40
  special  = false
}
locals {
  credentials = {
    os = {
      host                                 = aws_db_instance.postgresql.address
      port                                 = "5432"
      database                             = "fiap_os"
      username                             = "fiap_os"
      password                             = random_password.database["os"].result
      ConnectionStrings__DefaultConnection = "Host=${aws_db_instance.postgresql.address};Port=5432;Database=fiap_os;Username=fiap_os;Password=${random_password.database["os"].result};Maximum Pool Size=10;SSL Mode=VerifyFull;Root Certificate=/certs/global-bundle.pem"
    }
    billing = {
      host                                 = aws_db_instance.postgresql.address
      port                                 = "5432"
      database                             = "fiap_billing"
      username                             = "fiap_billing"
      password                             = random_password.database["billing"].result
      ConnectionStrings__DefaultConnection = "Host=${aws_db_instance.postgresql.address};Port=5432;Database=fiap_billing;Username=fiap_billing;Password=${random_password.database["billing"].result};Maximum Pool Size=10;SSL Mode=VerifyFull;Root Certificate=/certs/global-bundle.pem"
    }
    execution = {
      host                    = aws_docdb_cluster.execution.endpoint
      port                    = "27017"
      database                = "fiap_execution"
      username                = "fiap_execution"
      password                = random_password.database["execution"].result
      Mongo__ConnectionString = "mongodb://fiap_execution:${random_password.database["execution"].result}@${aws_docdb_cluster.execution.endpoint}:27017/fiap_execution?authSource=admin&tls=true&replicaSet=rs0&readPreference=primary&retryWrites=false"
    }
    postgres_admin = {
      host     = aws_db_instance.postgresql.address
      port     = "5432"
      database = "postgres"
      username = aws_db_instance.postgresql.username
      password = random_password.database["postgres_admin"].result
    }
    documentdb_admin = {
      host                    = aws_docdb_cluster.execution.endpoint
      port                    = "27017"
      Mongo__ConnectionString = "mongodb://fiap_admin:${random_password.database["documentdb_admin"].result}@${aws_docdb_cluster.execution.endpoint}:27017/admin?authSource=admin&tls=true&replicaSet=rs0&readPreference=primary&retryWrites=false"
      database                = "admin"
      username                = aws_docdb_cluster.execution.master_username
      password                = random_password.database["documentdb_admin"].result
    }
  }
  secret_names = {
    os               = "fiap-os-database-credentials"
    billing          = "fiap-billing-database-credentials"
    execution        = "fiap-execution-database-credentials"
    postgres_admin   = "fiap-postgres-admin"
    documentdb_admin = "fiap-documentdb-admin"
  }
}
resource "aws_secretsmanager_secret" "database" {
  for_each                = local.secret_names
  name                    = each.value
  recovery_window_in_days = 0
}
resource "aws_secretsmanager_secret_version" "database" {
  for_each      = local.secret_names
  secret_id     = aws_secretsmanager_secret.database[each.key].id
  secret_string = jsonencode(local.credentials[each.key])
}
