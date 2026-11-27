variable "environment" {
  description = "Ambiente (dev o prod). Prefijo de nombres: xyz-<environment>-<recurso>."
  type        = string
}

variable "data_subnet_ids" {
  description = "Subnets private 4–6 de networking. RDS exige al menos 2 AZ."
  type        = list(string)
}