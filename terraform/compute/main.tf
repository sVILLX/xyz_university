# =============================================================================
# Módulo compute: piezas comunes
#   poc.tf             EC2 única de la Fase 2
#   launch_template.tf App Server (Fases 3–4)
#   alb.tf             ALB, Target Group y Listener
#   asg.tf             Auto Scaling Group y política target tracking
#   load_tester.tf     Generador de carga temporal (reemplaza a Cloud9)
# =============================================================================

locals {
  name_prefix = "xyz-${var.environment}"

  ami_id = coalesce(var.ami_id, data.aws_ami.ubuntu.id)

  # La app vive aquí en todas las instancias (POC y App Server).
  app_dir = "/opt/xyz-app/resources/codebase_partner"

  # Los tags de default_tags del provider no llegan a las instancias ni a los
  # volúmenes que crea un Launch Template; se copian a mano.
  instance_tags = merge(data.aws_default_tags.current.tags, {
    Environment = var.environment
  })
}

# Última Ubuntu 22.04 LTS (Jammy) de Canonical.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

data "aws_default_tags" "current" {}
