# =============================================================================
# Application Load Balancer internet-facing en public 1–3.
# =============================================================================

resource "aws_lb" "app" {
  #checkov:skip=CKV_AWS_91:Access logs fuera de alcance de la POC (costo de S3 y sin requisito en el SPECS)
  #checkov:skip=CKV_AWS_150:Sin deletion protection: destroy.yml debe poder borrar el ambiente al cerrar la sesión del lab
  #checkov:skip=CKV2_AWS_28:WAF fuera de alcance: la app es pública y sin autenticación según el SPECS
  #checkov:skip=CKV2_AWS_20:Sin HTTPS (no lo requiere el SPECS), no hay listener al cual redirigir
  name                       = "${local.name_prefix}-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [var.alb_sg_id]
  subnets                    = var.public_subnet_ids
  drop_invalid_header_fields = true
  enable_deletion_protection = false
  idle_timeout               = 60

  tags = {
    Name = "${local.name_prefix}-alb"
  }
}

resource "aws_lb_target_group" "app" {
  #checkov:skip=CKV_AWS_378:El tráfico ALB → instancia viaja por la VPC privada; la app solo habla HTTP
  name                 = "${local.name_prefix}-app-tg"
  port                 = var.app_port
  protocol             = "HTTP"
  target_type          = "instance"
  vpc_id               = var.vpc_id
  deregistration_delay = 30

  health_check {
    enabled             = true
    protocol            = "HTTP"
    path                = var.health_check_path
    port                = "traffic-port"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${local.name_prefix}-app-tg"
  }
}

resource "aws_lb_listener" "http" {
  #checkov:skip=CKV_AWS_2:El SPECS no requiere HTTPS ni dominio propio para la POC
  #checkov:skip=CKV_AWS_103:Sin TLS: el listener es HTTP por la misma razón
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = {
    Name = "${local.name_prefix}-http"
  }
}
