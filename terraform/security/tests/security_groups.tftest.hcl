# Pruebas de los Security Groups, la matriz de puertos y LabInstanceProfile.

variables {
  environment = "dev"
  vpc_id      = "vpc-0123456789abcdef0"
}

mock_provider "aws" {
  source = "./tests/mocks"
}

run "cinco_sgs_en_la_misma_vpc" {
  command = plan

  variables {
    enable_poc = true
  }

  assert {
    condition     = alltrue([for sg in [aws_security_group.alb, aws_security_group.app, aws_security_group.db, aws_security_group.endpoint, aws_security_group.poc[0]] : sg.vpc_id == "vpc-0123456789abcdef0"])
    error_message = "Todos los SGs deben vivir en la VPC de networking."
  }

  assert {
    condition     = aws_security_group.alb.name == "xyz-dev-alb-sg" && aws_security_group.db.name == "xyz-dev-db-sg" && aws_security_group.poc[0].name == "xyz-dev-poc-sg"
    error_message = "Los SGs deben llamarse xyz-<ambiente>-<capa>-sg."
  }
}

run "cadena_principal_por_referencia" {
  command = apply

  assert {
    condition     = aws_vpc_security_group_ingress_rule.alb_http_from_internet.cidr_ipv4 == "0.0.0.0/0" && aws_vpc_security_group_ingress_rule.alb_http_from_internet.from_port == 80
    error_message = "alb-sg debe aceptar 80/TCP desde internet."
  }

  assert {
    condition     = aws_vpc_security_group_egress_rule.alb_to_app.referenced_security_group_id == aws_security_group.app.id && aws_vpc_security_group_egress_rule.alb_to_app.from_port == 80
    error_message = "alb-sg debe salir solo hacia app-sg en app_port (health checks)."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.app_from_alb.referenced_security_group_id == aws_security_group.alb.id && aws_vpc_security_group_ingress_rule.app_from_alb.cidr_ipv4 == null
    error_message = "app-sg solo debe aceptar tráfico desde alb-sg."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.db_from_app.referenced_security_group_id == aws_security_group.app.id && aws_vpc_security_group_ingress_rule.db_from_app.from_port == 3306
    error_message = "db-sg debe aceptar 3306 solo desde app-sg."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.endpoint_from_app.referenced_security_group_id == aws_security_group.app.id && aws_vpc_security_group_ingress_rule.endpoint_from_app.from_port == 443
    error_message = "endpoint-sg debe aceptar 443 desde app-sg."
  }

  assert {
    condition     = aws_vpc_security_group_egress_rule.app_to_db.referenced_security_group_id == aws_security_group.db.id
    error_message = "app-sg debe poder salir a db-sg en 3306."
  }

  assert {
    condition     = aws_vpc_security_group_egress_rule.app_http_out.from_port == 80 && aws_vpc_security_group_egress_rule.app_https_out.from_port == 443
    error_message = "app-sg necesita salida 80/443 para el user_data (apt, npm, Secrets Manager)."
  }

  assert {
    condition     = output.alb_sg_id == aws_security_group.alb.id && output.app_sg_id == aws_security_group.app.id && output.db_sg_id == aws_security_group.db.id && output.endpoint_sg_id == aws_security_group.endpoint.id
    error_message = "Los outputs deben apuntar a cada SG."
  }
}

run "nunca_3306_a_internet" {
  command = plan

  variables {
    enable_poc    = true
    poc_ssh_cidrs = ["203.0.113.7/32"]
  }

  assert {
    condition = alltrue([
      for r in concat(
        [aws_vpc_security_group_ingress_rule.alb_http_from_internet, aws_vpc_security_group_ingress_rule.poc_app_from_internet[0]],
        values(aws_vpc_security_group_ingress_rule.poc_ssh),
      ) : r.from_port != 3306
    ])
    error_message = "Ninguna regla abierta por CIDR puede usar el 3306."
  }
}

run "sin_poc_por_defecto" {
  command = apply

  assert {
    condition     = length(aws_security_group.poc) == 0 && length(aws_vpc_security_group_ingress_rule.db_from_poc) == 0
    error_message = "Sin enable_poc no deben existir poc-sg ni la regla temporal hacia db-sg."
  }

  assert {
    condition     = output.poc_sg_id == null
    error_message = "poc_sg_id debe ser null sin enable_poc."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.poc_ssh) == 0
    error_message = "Sin enable_poc no debe haber SSH."
  }
}

run "poc_con_regla_temporal_hacia_db" {
  command = apply

  variables {
    enable_poc    = true
    poc_ssh_cidrs = ["203.0.113.7/32"]
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.db_from_poc[0].referenced_security_group_id == aws_security_group.poc[0].id && aws_vpc_security_group_egress_rule.poc_to_db[0].referenced_security_group_id == aws_security_group.db.id
    error_message = "La migración necesita poc-sg → db-sg en 3306 (ingress y egress)."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.poc_app_from_internet[0].from_port == 80
    error_message = "poc-sg debe aceptar app_port desde internet (prueba de la Fase 2)."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.poc_ssh["203.0.113.7/32"].from_port == 22
    error_message = "poc_ssh_cidrs debe abrir el 22 solo a esos CIDRs."
  }

  assert {
    condition     = length(aws_vpc_security_group_egress_rule.poc_http_out) == 1 && length(aws_vpc_security_group_egress_rule.poc_https_out) == 1
    error_message = "La POC necesita salida 80/443 para instalar paquetes."
  }

  assert {
    condition     = output.poc_sg_id == aws_security_group.poc[0].id
    error_message = "poc_sg_id debe apuntar a poc-sg."
  }
}

run "app_port_distinto_se_propaga" {
  command = plan

  variables {
    app_port   = 3000
    enable_poc = true
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.app_from_alb.from_port == 3000 && aws_vpc_security_group_egress_rule.alb_to_app.to_port == 3000 && aws_vpc_security_group_ingress_rule.poc_app_from_internet[0].from_port == 3000
    error_message = "app_port debe llegar a alb-sg → app-sg y a la POC."
  }
}

run "lab_instance_profile" {
  command = apply

  assert {
    condition     = output.instance_profile_name == "LabInstanceProfile"
    error_message = "compute debe recibir el nombre LabInstanceProfile."
  }

  assert {
    condition     = output.lab_role_arn == "arn:aws:iam::123456789012:role/LabRole"
    error_message = "lab_role_arn debe salir de LabRole."
  }
}

run "rechaza_ssh_abierto_a_internet" {
  command = plan

  variables {
    enable_poc    = true
    poc_ssh_cidrs = ["0.0.0.0/0"]
  }

  expect_failures = [var.poc_ssh_cidrs]
}

run "rechaza_perfil_con_otro_rol" {
  command = plan

  variables {
    lab_role_name = "OtroRol"
  }

  expect_failures = [data.aws_iam_instance_profile.lab]
}
