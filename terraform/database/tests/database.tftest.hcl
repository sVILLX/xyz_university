variables {
  environment     = "dev"
  data_subnet_ids = ["subnet-p4", "subnet-p5", "subnet-p6"]
  db_sg_id        = "sg-db"
}

mock_provider "aws" {
  source = "./tests/mocks"
}

run "subnet_group_con_las_subnets_de_datos" {
  command = plan

  assert {
    condition     = aws_db_subnet_group.main.name == "xyz-dev-db-subnet-group"
    error_message = "El subnet group debe llamarse xyz-<ambiente>-db-subnet-group."
  }

  assert {
    condition     = length(aws_db_subnet_group.main.subnet_ids) == 3 && contains(aws_db_subnet_group.main.subnet_ids, "subnet-p4")
    error_message = "El subnet group debe usar las 3 subnets de datos."
  }
}

run "rds_privada_single_az" {
  command = plan

  assert {
    condition     = aws_db_instance.main.identifier == "xyz-dev-db" && aws_db_instance.main.engine == "mysql"
    error_message = "La base debe llamarse xyz-<ambiente>-db y usar MySQL."
  }

  assert {
    condition     = aws_db_instance.main.publicly_accessible == false
    error_message = "La base NO debe ser pública."
  }

  assert {
    condition     = aws_db_instance.main.multi_az == false && aws_db_instance.main.availability_zone == "us-east-1a"
    error_message = "La base debe ser Single-AZ en us-east-1a (private 4)."
  }

  assert {
    condition     = contains(aws_db_instance.main.vpc_security_group_ids, "sg-db") && aws_db_instance.main.db_subnet_group_name == "xyz-dev-db-subnet-group"
    error_message = "La base debe usar el db-sg de security y el subnet group del módulo."
  }

  assert {
    condition     = aws_db_instance.main.monitoring_interval == 0 && aws_db_instance.main.storage_encrypted == true
    error_message = "Sin enhanced monitoring y con almacenamiento cifrado."
  }
}

run "dev_se_puede_destruir" {
  command = plan

  assert {
    condition     = aws_db_instance.main.deletion_protection == false && aws_db_instance.main.skip_final_snapshot == true
    error_message = "En dev la base se debe poder destruir sin snapshot final."
  }
}

run "prod_protege_la_base" {
  command = plan

  variables {
    environment              = "prod"
    db_deletion_protection   = true
    db_skip_final_snapshot   = false
    db_backup_retention_days = 7
  }

  assert {
    condition     = aws_db_instance.main.deletion_protection == true && aws_db_instance.main.backup_retention_period == 7
    error_message = "En prod la base debe estar protegida y con 7 días de respaldo."
  }

  assert {
    condition     = aws_db_instance.main.final_snapshot_identifier == "xyz-prod-db-final"
    error_message = "En prod se debe tomar un snapshot final llamado xyz-prod-db-final."
  }
}

run "secreto_con_las_llaves_de_la_app" {
  command = apply

  assert {
    condition     = aws_secretsmanager_secret.db.name == "Mydbsecret" && aws_secretsmanager_secret.db.recovery_window_in_days == 0
    error_message = "El secreto debe llamarse Mydbsecret y borrarse sin periodo de recuperación."
  }

  assert {
    condition     = alltrue([for k in ["user", "password", "host", "db"] : contains(keys(jsondecode(aws_secretsmanager_secret_version.db.secret_string)), k)])
    error_message = "El secreto debe traer las llaves user, password, host y db."
  }

  assert {
    condition     = jsondecode(aws_secretsmanager_secret_version.db.secret_string).host == "xyz-dev-db.abc123.us-east-1.rds.amazonaws.com" && jsondecode(aws_secretsmanager_secret_version.db.secret_string).db == "STUDENTS" && jsondecode(aws_secretsmanager_secret_version.db.secret_string).user == "nodeapp"
    error_message = "host, db y user del secreto deben venir de la base y de las variables."
  }

  assert {
    condition     = output.secret_name == "Mydbsecret" && output.db_endpoint == "xyz-dev-db.abc123.us-east-1.rds.amazonaws.com"
    error_message = "Los outputs deben exponer el nombre del secreto y el endpoint."
  }
}

run "rechaza_otro_nombre_de_secreto" {
  command = plan

  variables {
    secret_name = "OtroSecreto"
  }

  expect_failures = [var.secret_name]
}

run "rechaza_ambiente_invalido" {
  command = plan

  variables {
    environment = "qa"
  }

  expect_failures = [var.environment]
}