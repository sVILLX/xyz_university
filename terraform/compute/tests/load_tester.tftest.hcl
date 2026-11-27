# Pruebas del generador de carga temporal.

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
  load_tester_sg_id     = "sg-load-tester"
}

mock_provider "aws" {
  source = "./tests/mocks"
}

run "sin_generador_por_defecto" {
  command = plan

  assert {
    condition     = length(aws_instance.load_tester) == 0
    error_message = "El generador de carga no debe existir por defecto."
  }
}

run "generador_apunta_al_alb" {
  command = apply

  variables {
    enable_load_tester = true
  }

  assert {
    condition     = strcontains(aws_instance.load_tester[0].user_data, "http://xyz-dev-alb-123456789.us-east-1.elb.amazonaws.com/")
    error_message = "loadtest debe apuntar al DNS del ALB."
  }

  assert {
    condition     = strcontains(aws_instance.load_tester[0].user_data, "--rps 1000 -c 500 -k -t 600")
    error_message = "Los parámetros por defecto deben ser los de Script-2 con 600 s."
  }

  assert {
    condition     = aws_instance.load_tester[0].vpc_security_group_ids == toset(["sg-load-tester"])
    error_message = "El generador debe usar load-tester-sg (security)."
  }

  assert {
    condition     = aws_instance.load_tester[0].associate_public_ip_address == true && aws_instance.load_tester[0].metadata_options[0].http_tokens == "required"
    error_message = "El generador necesita IP pública e IMDSv2 obligatorio."
  }

  assert {
    condition     = aws_instance.load_tester[0].subnet_id == "subnet-pub1"
    error_message = "El generador debe vivir en public 1."
  }
}

run "parametros_de_la_prueba" {
  command = plan

  variables {
    enable_load_tester = true
    load_test = {
      rps              = 200
      duration_seconds = 120
      path             = "/students"
    }
  }

  assert {
    condition     = strcontains(aws_instance.load_tester[0].user_data, "--rps 200 -c 500 -k -t 120")
    error_message = "Los parámetros de load_test deben llegar a loadtest (concurrency conserva su default)."
  }
}

run "generador_requiere_load_tester_sg" {
  command = plan

  variables {
    enable_load_tester = true
    load_tester_sg_id  = null
  }

  expect_failures = [aws_instance.load_tester]
}

run "rechaza_duracion_fuera_de_rango" {
  command = plan

  variables {
    enable_load_tester = true
    load_test = {
      duration_seconds = 7200
    }
  }

  expect_failures = [var.load_test]
}
