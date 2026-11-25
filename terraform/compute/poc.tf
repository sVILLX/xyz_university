# =============================================================================
# EC2 POC (Fase 2): una sola VM con la app y MySQL local, en public 1.
# Se accede por http://<poc_public_ip>. Se elimina con enable_poc = false
# cuando termina la migración a RDS (Fase 3).
# =============================================================================

resource "aws_instance" "poc" {
  count = var.enable_poc ? 1 : 0

  ami                         = local.ami_id
  instance_type               = var.poc_instance_type
  subnet_id                   = var.public_subnet_ids[0]
  vpc_security_group_ids      = [var.poc_sg_id]
  associate_public_ip_address = true #checkov:skip=CKV_AWS_88:La POC de la Fase 2 se prueba por su IP pública (SPECS Fase 2, Task 3)
  iam_instance_profile        = var.instance_profile_name
  key_name                    = var.poc_key_name
  monitoring                  = false #checkov:skip=CKV_AWS_126:POC temporal; el detailed monitoring tiene costo y no aporta

  user_data = templatefile("${path.module}/templates/poc_user_data.sh.tftpl", {
    app_dir      = local.app_dir
    app_port     = var.app_port
    app_code_url = var.app_code_url
  })

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  ebs_optimized = true

  tags = {
    Name = "${local.name_prefix}-poc"
  }

  volume_tags = merge(local.instance_tags, {
    Name = "${local.name_prefix}-poc"
  })

  lifecycle {
    # La POC guarda los datos en su disco: una AMI nueva o un cambio en el
    # user_data NO deben recrearla (se perderían los registros sin migrar).
    ignore_changes = [ami, user_data]

    precondition {
      condition     = var.poc_sg_id != null
      error_message = "enable_poc = true requiere poc_sg_id (módulo security)."
    }
  }
}
