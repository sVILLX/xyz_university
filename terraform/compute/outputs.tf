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

# =============================================================================
# App Server
# =============================================================================

output "launch_template_id" {
  description = "ID del Launch Template del App Server."
  value       = aws_launch_template.app.id
}

output "launch_template_latest_version" {
  description = "Última versión del Launch Template (la que usa el ASG)."
  value       = aws_launch_template.app.latest_version
}

output "ami_id" {
  description = "AMI de Ubuntu usada por las instancias."
  value       = local.ami_id
}
