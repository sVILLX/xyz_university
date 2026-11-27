locals {
  name_prefix = "xyz-${var.environment}"
}

resource "aws_db_subnet_group" "main" {
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = var.data_subnet_ids

  tags = {
    Name = "${local.name_prefix}-db-subnet-group"
  }
}

resource "random_password" "db" {
  length  = 20
  special = false
}

resource "aws_db_instance" "main" {
  #checkov:skip=CKV_AWS_157:El SPECS pide la base en una sola AZ (Single-AZ)
  #checkov:skip=CKV_AWS_118:El SPECS pide no activar enhanced monitoring
  #checkov:skip=CKV_AWS_293:Depende del ambiente (db_deletion_protection): true en prod, false en dev porque se destruye a diario
  #checkov:skip=CKV_AWS_133:Depende del ambiente (db_backup_retention_days): 7 días en prod, 0 en dev
  #checkov:skip=CKV_AWS_129:Sin exportar logs a CloudWatch para cuidar el presupuesto del lab
  identifier                 = "${local.name_prefix}-db"
  engine                     = "mysql"
  engine_version             = "8.4"
  instance_class             = var.db_instance_class
  auto_minor_version_upgrade = true

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name                             = var.db_name
  username                            = var.db_username
  password                            = random_password.db.result
  iam_database_authentication_enabled = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.db_sg_id]
  availability_zone      = var.db_availability_zone
  publicly_accessible    = false
  multi_az               = false

  backup_retention_period   = var.db_backup_retention_days
  deletion_protection       = var.db_deletion_protection
  skip_final_snapshot       = var.db_skip_final_snapshot
  final_snapshot_identifier = var.db_skip_final_snapshot ? null : "${local.name_prefix}-db-final"
  copy_tags_to_snapshot     = true

  monitoring_interval = 0

  tags = {
    Name = "${local.name_prefix}-db"
  }
}

resource "aws_secretsmanager_secret" "db" {
  #checkov:skip=CKV_AWS_149:Usa la llave administrada por AWS (aws/secretsmanager); una llave KMS propia cuesta extra y no aporta en la POC
  #checkov:skip=CKV2_AWS_57:Sin rotación automática: la app lee el secreto solo al arrancar (ver README de compute) y rotarlo la desconectaría de RDS
  name                    = var.secret_name
  recovery_window_in_days = 0

  tags = {
    Name = "${local.name_prefix}-db-secret"
  }
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    user     = var.db_username
    password = random_password.db.result
    host     = aws_db_instance.main.address
    db       = var.db_name
  })
}