# =============================================================================
# Módulo security
#   Security Groups encadenados por referencia (nunca por rango de IPs internas):
#     Internet ─80─▶ alb-sg ─app_port─▶ app-sg ─3306─▶ db-sg
#                                       app-sg ─443──▶ endpoint-sg
#     Internet ─app_port─▶ poc-sg ─3306 (temporal)─▶ db-sg
#   + lectura de LabInstanceProfile / LabRole.
#
#   Una regla = un recurso aws_vpc_security_group_*_rule. Terraform borra la
#   regla de salida "allow all" que AWS crea por defecto, así que toda salida
#   necesaria está declarada abajo.
# =============================================================================

locals {
  name_prefix = "xyz-${var.environment}"
  any_ipv4    = "0.0.0.0/0"
}

# =============================================================================
# Security Groups
# =============================================================================

resource "aws_security_group" "alb" {
  #checkov:skip=CKV2_AWS_5:Se asocia al ALB en el módulo compute (alb_sg_id)
  name        = "${local.name_prefix}-alb-sg"
  description = "ALB: HTTP desde internet hacia app-sg"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${local.name_prefix}-alb-sg"
  }
}

resource "aws_security_group" "app" {
  #checkov:skip=CKV2_AWS_5:Se asocia al Launch Template en el módulo compute (app_sg_id)
  name        = "${local.name_prefix}-app-sg"
  description = "App Server: solo acepta trafico desde alb-sg"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${local.name_prefix}-app-sg"
  }
}

resource "aws_security_group" "db" {
  #checkov:skip=CKV2_AWS_5:Se asocia a RDS en el módulo database (db_sg_id)
  name        = "${local.name_prefix}-db-sg"
  description = "RDS MySQL: solo acepta trafico desde app-sg (y poc-sg durante la migracion)"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${local.name_prefix}-db-sg"
  }
}

resource "aws_security_group" "endpoint" {
  #checkov:skip=CKV2_AWS_5:Se asocia al VPC Endpoint de Secrets Manager en networking (solo con enable_secrets_endpoint)
  name        = "${local.name_prefix}-endpoint-sg"
  description = "VPC Endpoint de Secrets Manager: HTTPS desde app-sg"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${local.name_prefix}-endpoint-sg"
  }
}

resource "aws_security_group" "poc" {
  #checkov:skip=CKV2_AWS_5:Se asocia a la EC2 POC en el módulo compute (poc_sg_id)
  count = var.enable_poc ? 1 : 0

  name        = "${local.name_prefix}-poc-sg"
  description = "EC2 POC de la Fase 2: app publica por IP y salida para instalar paquetes"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${local.name_prefix}-poc-sg"
  }
}

# =============================================================================
# alb-sg
# =============================================================================

resource "aws_vpc_security_group_ingress_rule" "alb_http_from_internet" {
  #checkov:skip=CKV_AWS_260:La app es pública y sin autenticación según el SPECS; el listener es HTTP :80
  security_group_id = aws_security_group.alb.id
  description       = "HTTP desde internet"
  cidr_ipv4         = local.any_ipv4
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80

  tags = {
    Name = "${local.name_prefix}-alb-in-http"
  }
}

# Reenvío de peticiones y health checks hacia las instancias.
resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Peticiones y health checks hacia app-sg"
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port

  tags = {
    Name = "${local.name_prefix}-alb-out-app"
  }
}

# =============================================================================
# app-sg
# =============================================================================

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "Puerto de la app solo desde alb-sg"
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port

  tags = {
    Name = "${local.name_prefix}-app-in-alb"
  }
}

# Salida por el NAT durante el user_data: apt (HTTP) y npm, el zip del código
# y Secrets Manager sin endpoint (HTTPS). Con endpoint, el 443 llega a
# endpoint-sg por esta misma regla.
resource "aws_vpc_security_group_egress_rule" "app_http_out" {
  security_group_id = aws_security_group.app.id
  description       = "HTTP saliente (repositorios apt) por el NAT"
  cidr_ipv4         = local.any_ipv4
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80

  tags = {
    Name = "${local.name_prefix}-app-out-http"
  }
}

resource "aws_vpc_security_group_egress_rule" "app_https_out" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS saliente (npm, codigo, Secrets Manager) por el NAT o el endpoint"
  cidr_ipv4         = local.any_ipv4
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443

  tags = {
    Name = "${local.name_prefix}-app-out-https"
  }
}

resource "aws_vpc_security_group_egress_rule" "app_to_db" {
  security_group_id            = aws_security_group.app.id
  description                  = "MySQL hacia db-sg"
  referenced_security_group_id = aws_security_group.db.id
  ip_protocol                  = "tcp"
  from_port                    = var.db_port
  to_port                      = var.db_port

  tags = {
    Name = "${local.name_prefix}-app-out-db"
  }
}

# =============================================================================
# db-sg (sin egress: la base no inicia conexiones)
# =============================================================================

resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "MySQL solo desde app-sg"
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = var.db_port
  to_port                      = var.db_port

  tags = {
    Name = "${local.name_prefix}-db-in-app"
  }
}

# Temporal: migración de datos de la POC a RDS. Desaparece con enable_poc = false.
resource "aws_vpc_security_group_ingress_rule" "db_from_poc" {
  count = var.enable_poc ? 1 : 0

  security_group_id            = aws_security_group.db.id
  description                  = "TEMPORAL: MySQL desde poc-sg para la migracion"
  referenced_security_group_id = aws_security_group.poc[0].id
  ip_protocol                  = "tcp"
  from_port                    = var.db_port
  to_port                      = var.db_port

  tags = {
    Name = "${local.name_prefix}-db-in-poc"
  }
}

# =============================================================================
# endpoint-sg (sin egress: solo responde)
# =============================================================================

resource "aws_vpc_security_group_ingress_rule" "endpoint_from_app" {
  security_group_id            = aws_security_group.endpoint.id
  description                  = "HTTPS desde app-sg hacia Secrets Manager"
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443

  tags = {
    Name = "${local.name_prefix}-endpoint-in-app"
  }
}

# =============================================================================
# poc-sg (solo con enable_poc)
# =============================================================================

resource "aws_vpc_security_group_ingress_rule" "poc_app_from_internet" {
  #checkov:skip=CKV_AWS_260:La POC de la Fase 2 se prueba por su IP pública (SPECS Fase 2, Task 3)
  count = var.enable_poc ? 1 : 0

  security_group_id = aws_security_group.poc[0].id
  description       = "Puerto de la app desde internet (prueba de la Fase 2)"
  cidr_ipv4         = local.any_ipv4
  ip_protocol       = "tcp"
  from_port         = var.app_port
  to_port           = var.app_port

  tags = {
    Name = "${local.name_prefix}-poc-in-app"
  }
}

resource "aws_vpc_security_group_ingress_rule" "poc_ssh" {
  for_each = var.enable_poc ? toset(var.poc_ssh_cidrs) : toset([])

  security_group_id = aws_security_group.poc[0].id
  description       = "SSH para la migracion (mysqldump) desde ${each.value}"
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22

  tags = {
    Name = "${local.name_prefix}-poc-in-ssh"
  }
}

# La POC está en public 1 con IP pública: sale directo por el IGW para
# instalar Node.js, MySQL y descargar el código.
resource "aws_vpc_security_group_egress_rule" "poc_http_out" {
  count = var.enable_poc ? 1 : 0

  security_group_id = aws_security_group.poc[0].id
  description       = "HTTP saliente (repositorios apt)"
  cidr_ipv4         = local.any_ipv4
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80

  tags = {
    Name = "${local.name_prefix}-poc-out-http"
  }
}

resource "aws_vpc_security_group_egress_rule" "poc_https_out" {
  count = var.enable_poc ? 1 : 0

  security_group_id = aws_security_group.poc[0].id
  description       = "HTTPS saliente (npm y codigo de la app)"
  cidr_ipv4         = local.any_ipv4
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443

  tags = {
    Name = "${local.name_prefix}-poc-out-https"
  }
}

resource "aws_vpc_security_group_egress_rule" "poc_to_db" {
  count = var.enable_poc ? 1 : 0

  security_group_id            = aws_security_group.poc[0].id
  description                  = "TEMPORAL: MySQL hacia db-sg para la migracion"
  referenced_security_group_id = aws_security_group.db.id
  ip_protocol                  = "tcp"
  from_port                    = var.db_port
  to_port                      = var.db_port

  tags = {
    Name = "${local.name_prefix}-poc-out-db"
  }
}

# =============================================================================
# Identidad: LabInstanceProfile / LabRole (solo lectura)
# Si el perfil no existe en la cuenta, el plan falla aquí y no al lanzar EC2.
# =============================================================================

data "aws_iam_instance_profile" "lab" {
  name = var.instance_profile_name

  lifecycle {
    postcondition {
      condition     = self.role_name == var.lab_role_name
      error_message = "${var.instance_profile_name} debe traer el rol ${var.lab_role_name} (lo necesita la app para leer el secreto)."
    }
  }
}

data "aws_iam_role" "lab" {
  name = data.aws_iam_instance_profile.lab.role_name
}
