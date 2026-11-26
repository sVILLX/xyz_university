# Pruebas del Launch Template del App Server.

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

run "launch_template_seguro" {
  command = plan

  assert {
    condition     = aws_launch_template.app.name == "xyz-dev-app-lt"
    error_message = "Nombre inesperado del Launch Template."
  }

  assert {
    condition     = aws_launch_template.app.metadata_options[0].http_tokens == "required"
    error_message = "IMDSv2 debe ser obligatorio."
  }

  assert {
    condition     = aws_launch_template.app.network_interfaces[0].associate_public_ip_address == "false"
    error_message = "Las instancias del App Server no deben tener IP pública."
  }

  assert {
    condition     = aws_launch_template.app.network_interfaces[0].security_groups == toset(["sg-app"])
    error_message = "Las instancias deben usar app-sg."
  }

  assert {
    condition     = aws_launch_template.app.iam_instance_profile[0].name == "LabInstanceProfile"
    error_message = "Las instancias deben usar LabInstanceProfile."
  }

  assert {
    condition     = aws_launch_template.app.block_device_mappings[0].ebs[0].encrypted == "true"
    error_message = "El disco debe ir cifrado."
  }

  assert {
    condition     = aws_launch_template.app.instance_type == "t3.micro"
    error_message = "El tipo de instancia por defecto debe ser t3.micro."
  }
}

run "user_data_lee_el_secreto_sin_credenciales" {
  command = plan

  assert {
    condition     = strcontains(base64decode(aws_launch_template.app.user_data), "SECRET_NAME=Mydbsecret")
    error_message = "El user_data debe esperar el secreto Mydbsecret."
  }

  assert {
    condition     = strcontains(base64decode(aws_launch_template.app.user_data), "SECRET_REGION=us-east-1")
    error_message = "El user_data debe usar la región de la app."
  }

  assert {
    condition     = !strcontains(base64decode(aws_launch_template.app.user_data), "student12")
    error_message = "El user_data del App Server no debe contener contraseñas."
  }

  assert {
    condition     = !strcontains(base64decode(aws_launch_template.app.user_data), "mysql-server")
    error_message = "El App Server no debe instalar MySQL local."
  }
}

run "prod_con_t3_small" {
  command = plan

  variables {
    environment   = "prod"
    instance_type = "t3.small"
  }

  assert {
    condition     = aws_launch_template.app.instance_type == "t3.small"
    error_message = "instance_type debe llegar al Launch Template."
  }

  assert {
    condition     = aws_launch_template.app.name == "xyz-prod-app-lt"
    error_message = "El nombre debe llevar el ambiente."
  }
}

run "rechaza_otro_nombre_de_secreto" {
  command = plan

  variables {
    secret_name = "otro-secreto"
  }

  expect_failures = [var.secret_name]
}

run "rechaza_region_distinta_a_la_de_la_app" {
  command = plan

  variables {
    region = "us-west-2"
  }

  expect_failures = [var.region]
}
