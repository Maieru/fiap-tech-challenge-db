resource "aws_security_group" "rds_postgresql" {
  name        = "fiap-rds-postgresql-sg"
  description = "Allow PostgreSQL access from the EKS nodes"
  vpc_id      = data.terraform_remote_state.aws-resources.outputs.vpc.id

  tags = {
    Name = "fiap-rds-postgresql-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_postgresql_from_eks" {
  security_group_id            = aws_security_group.rds_postgresql.id
  referenced_security_group_id = data.terraform_remote_state.aws-resources.outputs.eks.node_security_group
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_db_instance" "rds-postgresql-instance" {
  identifier              = "fiap-rds-postgresql-instance"
  allocated_storage       = 10
  db_name                 = "fiap_tech_challenge"
  engine                  = "postgres"
  engine_version          = "18.3"
  instance_class          = "db.t4g.micro"
  username                = var.db_username
  password                = var.db_password
  db_subnet_group_name    = data.terraform_remote_state.aws-resources.outputs.vpc.database_subnet_group_name
  vpc_security_group_ids  = [aws_security_group.rds_postgresql.id]
  publicly_accessible     = true
  skip_final_snapshot     = true
  backup_retention_period = 0
  apply_immediately       = true
}
