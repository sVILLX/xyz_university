variable "environment" {
  description = "Ambiente (dev o prod). Prefijo de nombres: xyz-<environment>-<recurso>."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment debe ser \"dev\" o \"prod\"."
  }
}

variable "data_subnet_ids" {
  description = "Subnets private 4–6 de networking. RDS exige al menos 2 AZ."
  type        = list(string)
}

variable "db_sg_id" {
  description = "db-sg de security (Santi). Solo acepta 3306 desde app-sg."
  type        = string
}

variable "db_instance_class" {
  description = "Tamaño de la máquina de RDS."
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Nombre de la base. La app y la POC usan STUDENTS."
  type        = string
  default     = "STUDENTS"
}

variable "db_username" {
  description = "Usuario de MySQL. Va en la base y en el secreto."
  type        = string
  default     = "nodeapp"
}

variable "db_availability_zone" {
  description = "AZ de la base (Single-AZ). us-east-1a = private 4."
  type        = string
  default     = "us-east-1a"
}

variable "db_backup_retention_days" {
  description = "Días de respaldo automático. dev 0, prod 7."
  type        = number
  default     = 0
}

variable "db_deletion_protection" {
  description = "true = AWS no deja borrar la base. dev false, prod true."
  type        = bool
  default     = false
}

variable "db_skip_final_snapshot" {
  description = "true = no se toma foto al destruir. dev true, prod false."
  type        = bool
  default     = true
}

variable "secret_name" {
  description = "Nombre del secreto. La app solo lee Mydbsecret (fijo en su código)."
  type        = string
  default     = "Mydbsecret"

  validation {
    condition     = var.secret_name == "Mydbsecret"
    error_message = "La app solo lee el secreto \"Mydbsecret\"."
  }
}