# Pruebas de la VPC, las 9 subnets, el IGW, el NAT y las tablas de ruteo.

variables {
  environment         = "dev"
  vpc_cidr            = "10.10.0.0/16"
  azs                 = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnet_cidrs = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]
  app_subnet_cidrs    = ["10.10.11.0/24", "10.10.12.0/24", "10.10.13.0/24"]
  data_subnet_cidrs   = ["10.10.21.0/24", "10.10.22.0/24", "10.10.23.0/24"]
}

mock_provider "aws" {
  source = "./tests/mocks"
}

run "vpc_con_dns" {
  command = plan

  assert {
    condition     = aws_vpc.main.cidr_block == "10.10.0.0/16"
    error_message = "La VPC debe usar vpc_cidr."
  }

  assert {
    condition     = aws_vpc.main.enable_dns_support && aws_vpc.main.enable_dns_hostnames
    error_message = "El VPC Endpoint con DNS privado necesita DNS support y DNS hostnames."
  }

  assert {
    condition     = aws_vpc.main.tags["Name"] == "xyz-dev-vpc"
    error_message = "La VPC debe llamarse xyz-<ambiente>-vpc."
  }
}

run "nueve_subnets_una_por_az_y_capa" {
  command = plan

  assert {
    condition     = length(aws_subnet.public) == 3 && length(aws_subnet.app) == 3 && length(aws_subnet.data) == 3
    error_message = "Deben existir 3 subnets por capa."
  }

  assert {
    condition     = aws_subnet.public["us-east-1a"].cidr_block == "10.10.1.0/24" && aws_subnet.app["us-east-1b"].cidr_block == "10.10.12.0/24" && aws_subnet.data["us-east-1c"].cidr_block == "10.10.23.0/24"
    error_message = "Cada CIDR debe caer en la AZ con el mismo índice."
  }

  assert {
    condition     = aws_subnet.data["us-east-1a"].tags["Role"] == "private 4" && aws_subnet.app["us-east-1a"].tags["Role"] == "private 1"
    error_message = "La numeración debe ser private 1–3 (app) y private 4–6 (datos)."
  }

  assert {
    condition     = aws_subnet.app["us-east-1a"].tags["Name"] == "xyz-dev-app-1a"
    error_message = "Las subnets deben llamarse xyz-<ambiente>-<capa>-<az>."
  }

  assert {
    condition     = alltrue([for s in concat(values(aws_subnet.public), values(aws_subnet.app), values(aws_subnet.data)) : s.map_public_ip_on_launch == false])
    error_message = "Ninguna subnet debe asignar IP pública por default."
  }
}

run "nat_unico_en_public_1" {
  command = apply

  assert {
    condition     = aws_nat_gateway.main.subnet_id == aws_subnet.public["us-east-1a"].id
    error_message = "El NAT debe vivir en public 1 (us-east-1a)."
  }

  assert {
    condition     = aws_eip.nat.domain == "vpc"
    error_message = "La EIP del NAT debe ser de VPC."
  }
}

run "rutas_por_capa" {
  command = apply

  assert {
    condition     = aws_route.public_internet.destination_cidr_block == "0.0.0.0/0" && aws_route.public_internet.route_table_id == aws_route_table.public.id
    error_message = "La tabla pública debe mandar 0.0.0.0/0 al IGW."
  }

  assert {
    condition     = aws_route.app_nat.destination_cidr_block == "0.0.0.0/0" && aws_route.app_nat.route_table_id == aws_route_table.app.id
    error_message = "La tabla de app debe mandar 0.0.0.0/0 al NAT."
  }

  assert {
    condition     = length(aws_route_table.data.route) == 0
    error_message = "La tabla de datos no debe tener rutas a internet."
  }

  assert {
    condition     = length(aws_route_table_association.public) == 3 && length(aws_route_table_association.app) == 3 && length(aws_route_table_association.data) == 3
    error_message = "Cada subnet debe estar asociada a la tabla de su capa."
  }
}

run "outputs_en_orden_de_azs" {
  command = apply

  assert {
    condition     = output.public_subnet_ids[0] == aws_subnet.public["us-east-1a"].id && output.app_subnet_ids[2] == aws_subnet.app["us-east-1c"].id && output.data_subnet_ids[1] == aws_subnet.data["us-east-1b"].id
    error_message = "Las listas de subnets deben seguir el orden de azs (compute usa public_subnet_ids[0])."
  }

  assert {
    condition     = output.vpc_id == "vpc-0123456789abcdef0" && output.vpc_cidr == "10.10.0.0/16"
    error_message = "vpc_id y vpc_cidr deben salir de la VPC."
  }

  assert {
    condition     = output.nat_gateway_id == "nat-0123456789abcdef0"
    error_message = "nat_gateway_id debe salir del NAT."
  }

  assert {
    condition     = length(aws_default_security_group.default.ingress) == 0 && length(aws_default_security_group.default.egress) == 0
    error_message = "El SG por defecto de la VPC no debe tener reglas."
  }
}

run "prod_usa_su_cidr" {
  command = plan

  variables {
    environment         = "prod"
    vpc_cidr            = "10.20.0.0/16"
    public_subnet_cidrs = ["10.20.1.0/24", "10.20.2.0/24", "10.20.3.0/24"]
    app_subnet_cidrs    = ["10.20.11.0/24", "10.20.12.0/24", "10.20.13.0/24"]
    data_subnet_cidrs   = ["10.20.21.0/24", "10.20.22.0/24", "10.20.23.0/24"]
  }

  assert {
    condition     = aws_vpc.main.tags["Name"] == "xyz-prod-vpc" && aws_subnet.public["us-east-1b"].cidr_block == "10.20.2.0/24"
    error_message = "prod debe usar su propio CIDR y prefijo."
  }
}

run "rechaza_una_sola_az" {
  command = plan

  variables {
    azs                 = ["us-east-1a"]
    public_subnet_cidrs = ["10.10.1.0/24"]
    app_subnet_cidrs    = ["10.10.11.0/24"]
    data_subnet_cidrs   = ["10.10.21.0/24"]
  }

  expect_failures = [var.azs]
}

run "rechaza_cidrs_desalineados_con_azs" {
  command = plan

  variables {
    app_subnet_cidrs = ["10.10.11.0/24", "10.10.12.0/24"]
  }

  expect_failures = [var.app_subnet_cidrs]
}

run "rechaza_cidrs_repetidos_entre_capas" {
  command = plan

  variables {
    data_subnet_cidrs = ["10.10.11.0/24", "10.10.22.0/24", "10.10.23.0/24"]
  }

  expect_failures = [var.data_subnet_cidrs]
}

run "rechaza_az_de_otra_region" {
  command = plan

  variables {
    azs = ["us-west-2a", "us-west-2b", "us-west-2c"]
  }

  expect_failures = [aws_vpc.main]
}
