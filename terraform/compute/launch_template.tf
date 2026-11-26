# =============================================================================
# Launch Template del App Server (Fases 3–4).
# Sin IP pública, IMDSv2 obligatorio, LabInstanceProfile para leer el secreto.
# =============================================================================

resource "aws_launch_template" "app" {
  name                   = "${local.name_prefix}-app-lt"
  description            = "App Server de XYZ University (${var.environment})"
  image_id               = local.ami_id
  instance_type          = var.instance_type
  update_default_version = true
  ebs_optimized          = true

  user_data = base64encode(templatefile("${path.module}/templates/user_data.sh.tftpl", {
    app_dir      = local.app_dir
    app_port     = var.app_port
    app_code_url = var.app_code_url
    secret_name  = var.secret_name
    region       = var.region
  }))

  iam_instance_profile {
    name = var.instance_profile_name
  }

  network_interfaces {
    associate_public_ip_address = false
    delete_on_termination       = true
    security_groups             = [var.app_sg_id]
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # Métricas cada minuto: el target tracking reacciona más rápido en la prueba de carga.
  monitoring {
    enabled = true
  }

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_type           = "gp3"
      volume_size           = var.root_volume_size
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.instance_tags, {
      Name = "${local.name_prefix}-app"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(local.instance_tags, {
      Name = "${local.name_prefix}-app"
    })
  }

  tags = {
    Name = "${local.name_prefix}-app-lt"
  }
}
