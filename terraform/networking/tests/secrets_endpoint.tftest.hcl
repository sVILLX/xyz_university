# Pruebas del VPC Endpoint de Secrets Manager.

variables {
  environment         = "prod"
  vpc_cidr            = "10.20.0.0/16"
  public_subnet_cidrs = ["10.20.1.0/24", "10.20.2.0/24", "10.20.3.0/24"]
  app_subnet_cidrs    = ["10.20.11.0/24", "10.20.12.0/24", "10.20.13.0/24"]
  data_subnet_cidrs   = ["10.20.21.0/24", "10.20.22.0/24", "10.20.23.0/24"]
  endpoint_sg_id      = "sg-endpoint"
}

mock_provider "aws" {
  source = "./tests/mocks"
}

run "sin_endpoint_por_defecto" {
  command = apply

  assert {
    condition     = length(aws_vpc_endpoint.secretsmanager) == 0
    error_message = "El endpoint no debe existir si enable_secrets_endpoint = false (dev)."
  }

  assert {
    condition     = output.secrets_endpoint_id == null
    error_message = "secrets_endpoint_id debe ser null sin endpoint."
  }
}

run "endpoint_privado_en_la_capa_app" {
  command = apply

  variables {
    enable_secrets_endpoint = true
  }

  assert {
    condition     = aws_vpc_endpoint.secretsmanager[0].service_name == "com.amazonaws.us-east-1.secretsmanager" && aws_vpc_endpoint.secretsmanager[0].vpc_endpoint_type == "Interface"
    error_message = "Debe ser un Interface Endpoint de Secrets Manager en la región del provider."
  }

  assert {
    condition     = aws_vpc_endpoint.secretsmanager[0].private_dns_enabled == true
    error_message = "Con DNS privado la app usa el endpoint sin cambiar su código."
  }

  assert {
    condition     = aws_vpc_endpoint.secretsmanager[0].subnet_ids == toset([for az in var.azs : aws_subnet.app[az].id])
    error_message = "El endpoint debe tener una interfaz en cada subnet de app."
  }

  assert {
    condition     = aws_vpc_endpoint.secretsmanager[0].security_group_ids == toset(["sg-endpoint"])
    error_message = "El endpoint debe usar endpoint-sg."
  }

  assert {
    condition     = aws_vpc_endpoint.secretsmanager[0].tags["Name"] == "xyz-prod-secretsmanager-vpce"
    error_message = "Nombre inesperado del endpoint."
  }
}

run "endpoint_requiere_endpoint_sg" {
  command = plan

  variables {
    enable_secrets_endpoint = true
    endpoint_sg_id          = null
  }

  expect_failures = [aws_vpc_endpoint.secretsmanager]
}
