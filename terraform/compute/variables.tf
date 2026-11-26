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

variable "ami_id" {
  description = "AMI fija opcional. Si es null se usa la última Ubuntu 22.04 LTS de Canonical (cambia cuando Canonical publica una nueva y provoca un instance refresh)."
  type        = string
  default     = null
}

variable "app_code_url" {
  description = "URL del zip con el código Node.js de la aplicación (proporcionado por AWS Academy, no se modifica)."
  type        = string
  default     = "https://aws-tc-largeobjects.s3.us-west-2.amazonaws.com/CUR-TF-200-ACCAP1-1-91571/1-lab-capstone-project-1/code.zip"
}

variable "app_port" {
  description = "Puerto en el que escucha la app (variable APP_PORT). Debe coincidir con la regla alb-sg → app-sg del módulo security."
  type        = number
  default     = 80

  validation {
    condition     = var.app_port >= 1 && var.app_port <= 65535
    error_message = "app_port debe estar entre 1 y 65535."
  }
}

variable "root_volume_size" {
  description = "Tamaño en GiB del disco raíz (gp3, cifrado) de las instancias."
  type        = number
  default     = 10

  validation {
    condition     = var.root_volume_size >= 8
    error_message = "La AMI de Ubuntu necesita al menos 8 GiB."
  }
}

# =============================================================================
# Entradas de otros módulos
# =============================================================================

variable "public_subnet_ids" {
  description = "Subnets públicas public 1–3 (networking). ALB, POC y generador de carga."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "El ALB necesita al menos 2 subnets públicas en AZ distintas."
  }
}

variable "instance_profile_name" {
  description = "Nombre del instance profile existente (security). En AWS Academy: LabInstanceProfile."
  type        = string
}

# =============================================================================
# EC2 POC (Fase 2)
# =============================================================================

variable "enable_poc" {
  description = "Crea la EC2 única de la Fase 2 (app + MySQL local) en public 1. Desactivar al terminar la migración."
  type        = bool
  default     = false
}

variable "poc_sg_id" {
  description = "poc-sg (security). Obligatorio cuando enable_poc = true."
  type        = string
  default     = null
}

variable "poc_instance_type" {
  description = "Tipo de instancia de la POC."
  type        = string
  default     = "t3.micro"
}

variable "poc_key_name" {
  description = "Key pair para entrar por SSH a la POC (migración con mysqldump). En AWS Academy: vockey. null = sin llave."
  type        = string
  default     = "vockey"
}

# =============================================================================
# App Server (Launch Template)
# =============================================================================

variable "region" {
  description = "Región de AWS. El código de la app tiene us-east-1 fijo en app/config/config.js, así que no puede ser otra."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = var.region == "us-east-1"
    error_message = "La app lee Secrets Manager en us-east-1 (valor fijo en config.js); region debe ser \"us-east-1\"."
  }
}

variable "app_sg_id" {
  description = "app-sg (security). Solo acepta app_port desde alb-sg."
  type        = string
}

variable "secret_name" {
  description = "Nombre del secreto con las credenciales de RDS (database). La app tiene \"Mydbsecret\" fijo en config.js."
  type        = string
  default     = "Mydbsecret"

  validation {
    condition     = var.secret_name == "Mydbsecret"
    error_message = "La app solo lee el secreto \"Mydbsecret\" (valor fijo en app/config/config.js)."
  }
}

variable "instance_type" {
  description = "Tipo de instancia del App Server."
  type        = string
  default     = "t3.micro"
}
