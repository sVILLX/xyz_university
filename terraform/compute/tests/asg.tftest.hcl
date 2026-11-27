# Pruebas del Auto Scaling Group y la política de escalado.

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

run "asg_prod" {
  # Va primero: con command = plan no deja estado, así que crea el ASG desde cero.
  command = plan

  variables {
    environment = "prod"
    asg_min     = 2
    asg_desired = 3
    asg_max     = 6
    cpu_target  = 50
  }

  assert {
    condition     = aws_autoscaling_group.app.min_size == 2 && aws_autoscaling_group.app.desired_capacity == 3 && aws_autoscaling_group.app.max_size == 6
    error_message = "prod debe ser 2/3/6."
  }

  assert {
    condition     = aws_autoscaling_policy.cpu.target_tracking_configuration[0].target_value == 50
    error_message = "prod debe escalar al 50 % de CPU."
  }
}

run "asg_dev" {
  command = apply

  assert {
    condition     = aws_autoscaling_group.app.min_size == 1 && aws_autoscaling_group.app.desired_capacity == 1 && aws_autoscaling_group.app.max_size == 2
    error_message = "dev debe ser 1/1/2."
  }

  assert {
    condition     = aws_autoscaling_group.app.vpc_zone_identifier == toset(["subnet-app1", "subnet-app2", "subnet-app3"])
    error_message = "El ASG debe estar en private 1–3."
  }

  assert {
    condition     = aws_autoscaling_group.app.health_check_type == "ELB" && aws_autoscaling_group.app.health_check_grace_period == 300
    error_message = "El ASG debe usar health check ELB con 300 s de gracia."
  }

  assert {
    condition     = aws_autoscaling_group.app.target_group_arns == toset([aws_lb_target_group.app.arn])
    error_message = "El ASG debe registrarse en el Target Group."
  }

  assert {
    condition     = aws_autoscaling_group.app.launch_template[0].id == aws_launch_template.app.id
    error_message = "El ASG debe usar el Launch Template del App Server."
  }

  assert {
    condition     = aws_autoscaling_group.app.instance_refresh[0].strategy == "Rolling"
    error_message = "El ASG debe hacer instance refresh al cambiar el Launch Template."
  }

  assert {
    condition     = aws_autoscaling_policy.cpu.policy_type == "TargetTrackingScaling" && aws_autoscaling_policy.cpu.target_tracking_configuration[0].target_value == 70
    error_message = "dev debe escalar por target tracking al 70 % de CPU."
  }

  assert {
    condition     = aws_autoscaling_policy.cpu.target_tracking_configuration[0].predefined_metric_specification[0].predefined_metric_type == "ASGAverageCPUUtilization"
    error_message = "La métrica debe ser ASGAverageCPUUtilization."
  }

  assert {
    condition     = output.asg_name == "xyz-dev-app-asg"
    error_message = "asg_name inesperado."
  }
}

run "terraform_no_pisa_la_capacidad_del_escalado" {
  # Mismo estado que asg_dev: cambiar asg_desired no debe mover desired_capacity
  # (la controla la política target tracking).
  command = plan

  variables {
    asg_desired = 2
  }

  assert {
    condition     = aws_autoscaling_group.app.desired_capacity == 1
    error_message = "desired_capacity debe ignorarse después de crear el ASG."
  }
}

run "rechaza_desired_fuera_de_rango" {
  command = plan

  variables {
    asg_min     = 2
    asg_desired = 1
    asg_max     = 6
  }

  expect_failures = [var.asg_desired]
}

run "rechaza_cpu_target_fuera_de_rango" {
  command = plan

  variables {
    cpu_target = 95
  }

  expect_failures = [var.cpu_target]
}
