# =============================================================================
# Generales
# =============================================================================

variable "environment" {
  description = "Ambiente (dev o prod). Se usa como prefijo de nombres: xyz-<environment>-<recurso>."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment debe ser \"dev\" o \"prod\"."
  }
}

# =============================================================================
# VPC y subnets
# =============================================================================

variable "vpc_cidr" {
  description = "Bloque CIDR de la VPC. dev: 10.10.0.0/16 · prod: 10.20.0.0/16 (sin traslape)."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && tonumber(split("/", var.vpc_cidr)[1]) <= 24
    error_message = "vpc_cidr debe ser un CIDR IPv4 válido de /24 o más grande (p. ej. 10.10.0.0/16)."
  }
}

variable "azs" {
  description = "Zonas de disponibilidad, en orden. El índice i corresponde a public i+1, private i+1 y private i+4. La primera aloja el NAT y la POC."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]

  validation {
    condition     = length(var.azs) >= 2 && length(distinct(var.azs)) == length(var.azs)
    error_message = "Se necesitan al menos 2 AZ distintas (el ALB y el DB Subnet Group de RDS lo exigen)."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDRs de public 1–3, en el mismo orden que azs. Tercer octeto 1–3."
  type        = list(string)

  validation {
    condition     = alltrue([for c in var.public_subnet_cidrs : can(cidrhost(c, 0))])
    error_message = "Todos los public_subnet_cidrs deben ser CIDRs IPv4 válidos."
  }

  validation {
    condition     = length(var.public_subnet_cidrs) == length(var.azs)
    error_message = "public_subnet_cidrs debe tener un CIDR por cada AZ de azs."
  }
}

variable "app_subnet_cidrs" {
  description = "CIDRs de private 1–3 (capa app), en el mismo orden que azs. Tercer octeto 11–13."
  type        = list(string)

  validation {
    condition     = alltrue([for c in var.app_subnet_cidrs : can(cidrhost(c, 0))])
    error_message = "Todos los app_subnet_cidrs deben ser CIDRs IPv4 válidos."
  }

  validation {
    condition     = length(var.app_subnet_cidrs) == length(var.azs)
    error_message = "app_subnet_cidrs debe tener un CIDR por cada AZ de azs."
  }
}

variable "data_subnet_cidrs" {
  description = "CIDRs de private 4–6 (capa datos), en el mismo orden que azs. Tercer octeto 21–23."
  type        = list(string)

  validation {
    condition     = alltrue([for c in var.data_subnet_cidrs : can(cidrhost(c, 0))])
    error_message = "Todos los data_subnet_cidrs deben ser CIDRs IPv4 válidos."
  }

  validation {
    condition     = length(var.data_subnet_cidrs) == length(var.azs)
    error_message = "data_subnet_cidrs debe tener un CIDR por cada AZ de azs."
  }

  validation {
    condition = length(distinct(concat(var.public_subnet_cidrs, var.app_subnet_cidrs, var.data_subnet_cidrs))) == (
      length(var.public_subnet_cidrs) + length(var.app_subnet_cidrs) + length(var.data_subnet_cidrs)
    )
    error_message = "Los CIDRs de las subnets no pueden repetirse entre capas."
  }
}
