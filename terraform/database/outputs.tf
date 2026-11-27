output "db_endpoint" {
  description = "Dirección de RDS (sin puerto). La usan la migración y los outputs raíz."
  value       = aws_db_instance.main.address
}

output "db_name" {
  description = "Nombre de la base (STUDENTS). Lo usa la migración."
  value       = aws_db_instance.main.db_name
}

output "secret_name" {
  description = "Nombre del secreto (Mydbsecret). Lo usa compute en el user_data."
  value       = aws_secretsmanager_secret.db.name
}

output "secret_arn" {
  description = "ARN del secreto (diagnóstico)."
  value       = aws_secretsmanager_secret.db.arn
}