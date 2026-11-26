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
# Entradas de otros módulos
# =============================================================================

variable "vpc_id" {
  description = "VPC donde se crean los SGs (networking). Debe ser la misma que usan compute y database."
  type        = string
}

# =============================================================================
# Cadena principal: alb-sg → app-sg → db-sg / endpoint-sg
# =============================================================================

variable "app_port" {
  description = "Puerto en el que escucha la app (APP_PORT). Debe ser el mismo valor que recibe compute: lo usan alb-sg → app-sg y la POC."
  type        = number
  default     = 80

  validation {
    condition     = var.app_port >= 1 && var.app_port <= 65535
    error_message = "app_port debe estar entre 1 y 65535."
  }
}

variable "db_port" {
  description = "Puerto de MySQL en RDS. Nunca se abre a 0.0.0.0/0."
  type        = number
  default     = 3306

  validation {
    condition     = var.db_port >= 1 && var.db_port <= 65535
    error_message = "db_port debe estar entre 1 y 65535."
  }
}

# =============================================================================
# EC2 POC (Fase 2) y migración de datos
# =============================================================================

variable "enable_poc" {
  description = "Crea poc-sg y la regla temporal poc-sg → db-sg. Debe tener el mismo valor que enable_poc de compute. Desactivar al terminar la migración."
  type        = bool
  default     = false
}

variable "poc_ssh_cidrs" {
  description = "CIDRs (IPv4) que pueden entrar por SSH (22) a la POC para el mysqldump de la migración (key pair vockey de compute). [] = sin SSH."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.poc_ssh_cidrs : can(cidrhost(c, 0)) && c != "0.0.0.0/0"])
    error_message = "poc_ssh_cidrs debe contener CIDRs IPv4 válidos y nunca 0.0.0.0/0 (usa tu IP/32)."
  }
}

# =============================================================================
# Identidad (AWS Academy: solo lectura, no se pueden crear roles)
# =============================================================================

variable "instance_profile_name" {
  description = "Instance profile existente que usan las instancias para leer el secreto."
  type        = string
  default     = "LabInstanceProfile"
}

variable "lab_role_name" {
  description = "Rol IAM que debe traer el instance profile."
  type        = string
  default     = "LabRole"
}
