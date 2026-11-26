# Pruebas del Application Load Balancer, Target Group y Listener.

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

run "alb_publico_en_subnets_publicas" {
  command = plan

  assert {
    condition     = aws_lb.app.internal == false && aws_lb.app.load_balancer_type == "application"
    error_message = "El ALB debe ser application e internet-facing."
  }

  assert {
    condition     = aws_lb.app.subnets == toset(["subnet-pub1", "subnet-pub2", "subnet-pub3"])
    error_message = "El ALB debe estar en public 1–3."
  }

  assert {
    condition     = aws_lb.app.security_groups == toset(["sg-alb"])
    error_message = "El ALB debe usar alb-sg."
  }

  assert {
    condition     = aws_lb.app.drop_invalid_header_fields == true
    error_message = "El ALB debe descartar headers inválidos."
  }
}

run "target_group_y_health_check" {
  command = plan

  assert {
    condition     = aws_lb_target_group.app.port == 80 && aws_lb_target_group.app.protocol == "HTTP"
    error_message = "El Target Group debe apuntar al puerto de la app por HTTP."
  }

  assert {
    condition     = aws_lb_target_group.app.health_check[0].path == "/" && aws_lb_target_group.app.health_check[0].matcher == "200"
    error_message = "El health check debe ser GET / con 200."
  }

  assert {
    condition     = aws_lb_target_group.app.deregistration_delay == "30"
    error_message = "deregistration_delay debe ser 30 s."
  }
}

run "listener_http_80" {
  command = apply

  assert {
    condition     = aws_lb_listener.http.port == 80 && aws_lb_listener.http.protocol == "HTTP"
    error_message = "El listener debe ser HTTP :80."
  }

  assert {
    condition     = aws_lb_listener.http.default_action[0].target_group_arn == aws_lb_target_group.app.arn
    error_message = "El listener debe reenviar al Target Group."
  }

  assert {
    condition     = output.alb_url == "http://xyz-dev-alb-123456789.us-east-1.elb.amazonaws.com"
    error_message = "alb_url debe construirse con el DNS del ALB."
  }
}

run "rechaza_health_check_sin_slash" {
  command = plan

  variables {
    health_check_path = "students"
  }

  expect_failures = [var.health_check_path]
}
