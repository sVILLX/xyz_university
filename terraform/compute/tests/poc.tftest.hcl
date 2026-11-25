# Pruebas de la EC2 POC (Fase 2).

variables {
  environment           = "dev"
  vpc_id                = "vpc-0123456789abcdef0"
  public_subnet_ids     = ["subnet-pub1", "subnet-pub2", "subnet-pub3"]
  app_subnet_ids        = ["subnet-app1", "subnet-app2", "subnet-app3"]
  alb_sg_id             = "sg-alb"
  app_sg_id             = "sg-app"
  poc_sg_id             = "sg-poc"
  instance_profile_name = "LabInstanceProfile"
  secret_name           = "Mydbsecret"
}

mock_provider "aws" {
  source = "./tests/mocks"
}

run "sin_poc_por_defecto" {
  command = plan

  assert {
    condition     = length(aws_instance.poc) == 0
    error_message = "La POC no debe existir si enable_poc = false."
  }
}

run "poc_en_subnet_publica_con_ip_publica" {
  command = plan

  variables {
    enable_poc = true
  }

  assert {
    condition     = aws_instance.poc[0].subnet_id == "subnet-pub1"
    error_message = "La POC debe vivir en public 1."
  }

  assert {
    condition     = aws_instance.poc[0].associate_public_ip_address == true
    error_message = "La POC se prueba por su IP pública."
  }

  assert {
    condition     = aws_instance.poc[0].metadata_options[0].http_tokens == "required"
    error_message = "IMDSv2 debe ser obligatorio."
  }

  assert {
    condition     = aws_instance.poc[0].iam_instance_profile == "LabInstanceProfile"
    error_message = "La POC debe usar LabInstanceProfile."
  }

  assert {
    condition     = aws_instance.poc[0].key_name == "vockey"
    error_message = "La POC debe usar el key pair vockey por defecto."
  }

  assert {
    condition     = aws_instance.poc[0].root_block_device[0].encrypted == true
    error_message = "El disco de la POC debe ir cifrado."
  }
}

run "poc_user_data_instala_mysql_local" {
  command = plan

  variables {
    enable_poc = true
  }

  assert {
    condition     = strcontains(aws_instance.poc[0].user_data, "mysql-server")
    error_message = "El user_data de la POC debe instalar MySQL."
  }

  assert {
    condition     = strcontains(aws_instance.poc[0].user_data, "Environment=APP_PORT=$APP_PORT") && strcontains(aws_instance.poc[0].user_data, "APP_PORT=\"80\"")
    error_message = "El user_data de la POC debe pasar APP_PORT a la app."
  }

  assert {
    condition     = !strcontains(aws_instance.poc[0].user_data, "bind-address = 0.0.0.0")
    error_message = "MySQL de la POC no debe escuchar en todas las interfaces."
  }
}

run "poc_requiere_poc_sg" {
  command = plan

  variables {
    enable_poc = true
    poc_sg_id  = null
  }

  expect_failures = [aws_instance.poc]
}
