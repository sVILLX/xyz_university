# =============================================================================
# Security Groups
# =============================================================================

output "alb_sg_id" {
  description = "alb-sg. Lo consume compute (ALB)."
  value       = aws_security_group.alb.id
}

output "app_sg_id" {
  description = "app-sg. Lo consume compute (Launch Template)."
  value       = aws_security_group.app.id
}

output "db_sg_id" {
  description = "db-sg. Lo consume database (RDS)."
  value       = aws_security_group.db.id
}

output "endpoint_sg_id" {
  description = "endpoint-sg. Lo consume networking (VPC Endpoint de Secrets Manager)."
  value       = aws_security_group.endpoint.id
}

output "poc_sg_id" {
  description = "poc-sg. Lo consume compute (EC2 POC). null si enable_poc = false."
  value       = one(aws_security_group.poc[*].id)
}

# =============================================================================
# Identidad
# =============================================================================

output "instance_profile_name" {
  description = "Nombre del instance profile (LabInstanceProfile). Lo consume compute (Launch Template y POC)."
  value       = data.aws_iam_instance_profile.lab.name
}

output "instance_profile_arn" {
  description = "ARN del instance profile (diagnóstico)."
  value       = data.aws_iam_instance_profile.lab.arn
}

output "lab_role_arn" {
  description = "ARN de LabRole, el rol que asumen las instancias (diagnóstico)."
  value       = data.aws_iam_role.lab.arn
}
