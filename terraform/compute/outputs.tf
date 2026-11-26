# =============================================================================
# EC2 POC (Fase 2)
# =============================================================================

output "poc_public_ip" {
  description = "IP pública de la POC: http://<ip> para la prueba CRUD de la Fase 2. null si enable_poc = false."
  value       = one(aws_instance.poc[*].public_ip)
}

output "poc_private_ip" {
  description = "IP privada de la POC (referencia para la migración). null si enable_poc = false."
  value       = one(aws_instance.poc[*].private_ip)
}

output "poc_instance_id" {
  description = "ID de la instancia POC. null si enable_poc = false."
  value       = one(aws_instance.poc[*].id)
}
