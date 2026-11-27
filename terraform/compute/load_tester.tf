# =============================================================================
# Generador de carga temporal (Fase 4, Task 4). Reemplaza a Cloud9 para
# correr Script-2 (loadtest) contra el ALB. Solo existe con enable_load_tester.
# Su SG (load-tester-sg) lo crea el módulo security: salida 80/443 a internet
# y SSH opcional desde load_tester_ssh_cidrs.
# =============================================================================

resource "aws_instance" "load_tester" {
  count = var.enable_load_tester ? 1 : 0

  ami                         = local.ami_id
  instance_type               = var.load_tester_instance_type
  subnet_id                   = var.public_subnet_ids[0]
  vpc_security_group_ids      = [var.load_tester_sg_id]
  associate_public_ip_address = true #checkov:skip=CKV_AWS_88:Sale a internet sin NAT y llega al DNS público del ALB, como un usuario real
  iam_instance_profile        = var.instance_profile_name
  key_name                    = var.load_tester_key_name
  monitoring                  = false #checkov:skip=CKV_AWS_126:Instancia temporal de prueba
  ebs_optimized               = true

  user_data = templatefile("${path.module}/templates/load_tester_user_data.sh.tftpl", {
    target_url       = "http://${aws_lb.app.dns_name}${var.load_test.path}"
    rps              = var.load_test.rps
    concurrency      = var.load_test.concurrency
    duration_seconds = var.load_test.duration_seconds
  })
  user_data_replace_on_change = true

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

  tags = {
    Name = "${local.name_prefix}-load-tester"
  }

  volume_tags = merge(local.instance_tags, {
    Name = "${local.name_prefix}-load-tester"
  })

  # Empieza cuando el ASG ya existe, para que haya a quién mandarle carga.
  depends_on = [aws_autoscaling_group.app]

  lifecycle {
    precondition {
      condition     = var.load_tester_sg_id != null
      error_message = "enable_load_tester = true requiere load_tester_sg_id (módulo security)."
    }
  }
}
