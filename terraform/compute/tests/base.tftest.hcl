# Pruebas de las entradas generales del módulo y la AMI.

variables {
  environment           = "dev"
  vpc_id                = "vpc-0123456789abcdef0"
  public_subnet_ids     = ["subnet-pub1", "subnet-pub2", "subnet-pub3"]
  app_subnet_ids        = ["subnet-app1", "subnet-app2", "subnet-app3"]
  alb_sg_id             = "sg-alb"
  app_sg_id             = "sg-app"
  poc_sg_id             = "sg-poc"
  instance_profile_name = "LabInstanceProfile"
  secret_name           = "Mydbsecret"
}

mock_provider "aws" {
  source = "./tests/mocks"
}

run "ami_por_defecto_es_ubuntu_de_canonical" {
  command = plan

  assert {
    condition     = contains(data.aws_ami.ubuntu.owners, "099720109477")
    error_message = "La AMI debe ser de Canonical."
  }

  assert {
    condition     = local.ami_id == "ami-0123456789abcdef0"
    error_message = "Sin ami_id fijo se debe usar la AMI del data source."
  }

  assert {
    condition     = local.name_prefix == "xyz-dev"
    error_message = "El prefijo de nombres debe ser xyz-<ambiente>."
  }
}

run "ami_fija_tiene_prioridad" {
  command = plan

  variables {
    ami_id = "ami-fixed"
  }

  assert {
    condition     = local.ami_id == "ami-fixed"
    error_message = "ami_id debe sobrescribir la AMI del data source."
  }
}

run "rechaza_ambiente_invalido" {
  command = plan

  variables {
    environment = "qa"
  }

  expect_failures = [var.environment]
}

run "rechaza_una_sola_subnet_publica" {
  command = plan

  variables {
    public_subnet_ids = ["subnet-pub1"]
  }

  expect_failures = [var.public_subnet_ids]
}
