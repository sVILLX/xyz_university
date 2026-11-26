# =============================================================================
# Módulo networking
#   VPC en 3 AZ con 9 subnets en tres capas:
#     public  1–3 → ALB, NAT, POC         · 0.0.0.0/0 → Internet Gateway
#     private 1–3 → App Server (ASG)      · 0.0.0.0/0 → NAT Gateway (public 1)
#     private 4–6 → RDS + DB Subnet Group · sin ruta a internet
# =============================================================================

locals {
  name_prefix = "xyz-${var.environment}"
  region      = data.aws_region.current.region

  # Un mapa por capa: AZ → { cidr, número de subnet }. for_each por AZ (y no
  # count) para que quitar una AZ de la lista no renumere ni recree las demás.
  public_subnets = {
    for i, az in var.azs : az => { cidr = var.public_subnet_cidrs[i], number = i + 1 }
  }
  app_subnets = {
    for i, az in var.azs : az => { cidr = var.app_subnet_cidrs[i], number = i + 1 }
  }
  data_subnets = {
    for i, az in var.azs : az => { cidr = var.data_subnet_cidrs[i], number = i + 1 + length(var.azs) }
  }

  # "us-east-1a" → "1a", para nombres como xyz-dev-app-1a.
  az_suffix = { for az in var.azs : az => regex("[0-9]+[a-z]$", az) }

  # El NAT (y la POC de compute, que usa public_subnet_ids[0]) viven en la primera AZ.
  nat_az = var.azs[0]
}

data "aws_region" "current" {}

# =============================================================================
# VPC
# =============================================================================

resource "aws_vpc" "main" {
  #checkov:skip=CKV2_AWS_11:VPC Flow Logs fuera de alcance de la POC (costo de CloudWatch Logs y sin requisito en el SPECS)
  cidr_block = var.vpc_cidr

  # Los necesita el VPC Endpoint de Secrets Manager con DNS privado.
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }

  lifecycle {
    precondition {
      condition     = alltrue([for az in var.azs : startswith(az, local.region)])
      error_message = "Todas las AZ de azs deben pertenecer a la región del provider (${local.region})."
    }
  }
}

# El SG por defecto de la VPC queda sin reglas: nada debe usarlo. Todos los
# recursos usan los SG del módulo security.
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-default-sg-sin-reglas"
  }
}

# =============================================================================
# Subnets
# =============================================================================

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.key

  # Ningún recurso recibe IP pública por default: la POC la pide explícitamente
  # (associate_public_ip_address) y el ALB no la necesita.
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name_prefix}-public-${local.az_suffix[each.key]}"
    Tier = "public"
    Role = "public ${each.value.number}"
  }
}

resource "aws_subnet" "app" {
  for_each = local.app_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.key
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name_prefix}-app-${local.az_suffix[each.key]}"
    Tier = "app"
    Role = "private ${each.value.number}"
  }
}

resource "aws_subnet" "data" {
  for_each = local.data_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.key
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name_prefix}-data-${local.az_suffix[each.key]}"
    Tier = "data"
    Role = "private ${each.value.number}"
  }
}

# =============================================================================
# Internet Gateway y NAT Gateway (uno solo, en public 1, para ahorrar costo)
# =============================================================================

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${local.name_prefix}-nat-eip"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[local.nat_az].id

  tags = {
    Name = "${local.name_prefix}-nat-${local.az_suffix[local.nat_az]}"
  }

  # El NAT necesita que la VPC ya tenga salida a internet.
  depends_on = [aws_internet_gateway.main]
}

# =============================================================================
# Tablas de ruteo
# =============================================================================

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-public-rt"
    Tier = "public"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table" "app" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-app-rt"
    Tier = "app"
  }
}

resource "aws_route" "app_nat" {
  route_table_id         = aws_route_table.app.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}

# Capa de datos: solo la ruta local de la VPC (la crea AWS sola).
resource "aws_route_table" "data" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-data-rt"
    Tier = "data"
  }
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "app" {
  for_each = aws_subnet.app

  subnet_id      = each.value.id
  route_table_id = aws_route_table.app.id
}

resource "aws_route_table_association" "data" {
  for_each = aws_subnet.data

  subnet_id      = each.value.id
  route_table_id = aws_route_table.data.id
}

# =============================================================================
# VPC Endpoint de Secrets Manager (solo con enable_secrets_endpoint)
# Una interfaz por AZ en la capa app. Con DNS privado, el nombre público
# secretsmanager.<región>.amazonaws.com resuelve a estas IPs privadas y la app
# no cambia nada: el tráfico deja de pasar por el NAT.
# =============================================================================

resource "aws_vpc_endpoint" "secretsmanager" {
  count = var.enable_secrets_endpoint ? 1 : 0

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${local.region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for az in var.azs : aws_subnet.app[az].id]
  security_group_ids  = [var.endpoint_sg_id]
  private_dns_enabled = true

  tags = {
    Name = "${local.name_prefix}-secretsmanager-vpce"
  }

  lifecycle {
    precondition {
      condition     = var.endpoint_sg_id != null
      error_message = "enable_secrets_endpoint = true requiere endpoint_sg_id (módulo security). Sin él AWS usaría el SG por defecto, que no tiene reglas."
    }
  }
}
