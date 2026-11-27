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

# =============================================================================
# Application Load Balancer
# =============================================================================

output "alb_dns_name" {
  description = "DNS del ALB. Lo consumen los outputs raíz, smoke-test.sh y la prueba de carga."
  value       = aws_lb.app.dns_name
}

output "alb_url" {
  description = "URL de la aplicación."
  value       = "http://${aws_lb.app.dns_name}"
}

output "target_group_arn" {
  description = "ARN del Target Group (diagnóstico: aws elbv2 describe-target-health)."
  value       = aws_lb_target_group.app.arn
}

# =============================================================================
# Auto Scaling Group
# =============================================================================

output "asg_name" {
  description = "Nombre del Auto Scaling Group (evidencias de escalado)."
  value       = aws_autoscaling_group.app.name
}

# =============================================================================
# Generador de carga
# =============================================================================

output "load_tester_instance_id" {
  description = "ID del generador de carga (EC2 > Get system log para ver resultados). null si enable_load_tester = false."
  value       = one(aws_instance.load_tester[*].id)
}

output "load_tester_public_ip" {
  description = "IP pública del generador de carga (SSH opcional). null si enable_load_tester = false."
  value       = one(aws_instance.load_tester[*].public_ip)
}
