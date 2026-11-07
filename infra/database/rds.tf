resource "aws_security_group" "database" {
  name   = "fiap-databases"
  vpc_id = data.terraform_remote_state.aws-resources.outputs.vpc.id
}
resource "aws_vpc_security_group_ingress_rule" "database" {
  for_each                     = { postgresql = 5432, documentdb = 27017 }
  security_group_id            = aws_security_group.database.id
  referenced_security_group_id = data.terraform_remote_state.aws-resources.outputs.eks.node_security_group
  from_port                    = each.value
  to_port                      = each.value
  ip_protocol                  = "tcp"
}
resource "aws_db_instance" "postgresql" {
  identifier               = "fiap-microservices-postgresql"
  engine                   = "postgres"
  engine_version           = "18.3"
  instance_class           = "db.t4g.micro"
  allocated_storage        = 20
  storage_type             = "gp3"
  storage_encrypted        = true
  db_name                  = "postgres"
  username                 = "fiap_admin"
  password                 = random_password.database["postgres_admin"].result
  db_subnet_group_name     = data.terraform_remote_state.aws-resources.outputs.vpc.database_subnet_group_name
  vpc_security_group_ids   = [aws_security_group.database.id]
  publicly_accessible      = false
  multi_az                 = false
  skip_final_snapshot      = true
  backup_retention_period  = 0
  delete_automated_backups = true
  deletion_protection      = false
  apply_immediately        = true
}
resource "aws_docdb_subnet_group" "execution" {
  name       = "fiap-execution"
  subnet_ids = data.terraform_remote_state.aws-resources.outputs.vpc.database_subnet_ids
}
resource "aws_docdb_cluster" "execution" {
  cluster_identifier      = "fiap-execution"
  engine                  = "docdb"
  engine_version          = "5.0.0"
  master_username         = "fiap_admin"
  master_password         = random_password.database["documentdb_admin"].result
  db_subnet_group_name    = aws_docdb_subnet_group.execution.name
  vpc_security_group_ids  = [aws_security_group.database.id]
  storage_encrypted       = true
  backup_retention_period = 1
  skip_final_snapshot     = true
  deletion_protection     = false
  apply_immediately       = true
}
resource "aws_docdb_cluster_instance" "execution" {
  identifier         = "fiap-execution-1"
  cluster_identifier = aws_docdb_cluster.execution.id
  instance_class     = "db.t4g.medium"
  apply_immediately  = true
}
