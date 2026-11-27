# Las listas de subnets salen en el mismo orden que var.azs:
# [0] = us-east-1a (public 1 / private 1 / private 4), [1] = 1b, [2] = 1c.
# compute depende de ese orden: la POC usa public_subnet_ids[0].

output "vpc_id" {
  description = "ID de la VPC. Lo consumen security (SGs), compute (Target Group) y database."
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "Bloque CIDR de la VPC."
  value       = aws_vpc.main.cidr_block
}

output "azs" {
  description = "AZ usadas, en el mismo orden que las listas de subnets."
  value       = var.azs
}

output "public_subnet_ids" {
  description = "Subnets public 1–3 (compute: ALB y POC en public 1)."
  value       = [for az in var.azs : aws_subnet.public[az].id]
}

output "app_subnet_ids" {
  description = "Subnets private 1–3 (compute: Auto Scaling Group)."
  value       = [for az in var.azs : aws_subnet.app[az].id]
}

output "data_subnet_ids" {
  description = "Subnets private 4–6 (database: DB Subnet Group)."
  value       = [for az in var.azs : aws_subnet.data[az].id]
}

output "nat_gateway_id" {
  description = "ID del NAT Gateway en public 1 (diagnóstico)."
  value       = aws_nat_gateway.main.id
}

output "nat_public_ip" {
  description = "IP pública con la que salen a internet las instancias de la capa app."
  value       = aws_eip.nat.public_ip
}

output "secrets_endpoint_id" {
  description = "ID del VPC Endpoint de Secrets Manager. null si enable_secrets_endpoint = false."
  value       = one(aws_vpc_endpoint.secretsmanager[*].id)
}
