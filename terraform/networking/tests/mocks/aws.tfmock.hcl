# Valores falsos del provider AWS para `terraform test` (no se conecta a AWS).

mock_data "aws_region" {
  defaults = {
    region = "us-east-1"
  }
}

mock_resource "aws_vpc" {
  defaults = {
    id = "vpc-0123456789abcdef0"
  }
}

mock_resource "aws_internet_gateway" {
  defaults = {
    id = "igw-0123456789abcdef0"
  }
}

mock_resource "aws_nat_gateway" {
  defaults = {
    id = "nat-0123456789abcdef0"
  }
}

mock_resource "aws_eip" {
  defaults = {
    id        = "eipalloc-0123456789abcdef0"
    public_ip = "203.0.113.10"
  }
}
