# Valores falsos del provider AWS para `terraform test` (no se conecta a AWS).

mock_data "aws_ami" {
  defaults = {
    id = "ami-0123456789abcdef0"
  }
}

mock_data "aws_default_tags" {
  defaults = {
    tags = {
      Project   = "xyz-university"
      ManagedBy = "terraform"
    }
  }
}

mock_resource "aws_lb" {
  defaults = {
    arn      = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/xyz-dev-alb/0123456789abcdef"
    dns_name = "xyz-dev-alb-123456789.us-east-1.elb.amazonaws.com"
  }
}

mock_resource "aws_lb_target_group" {
  defaults = {
    arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/xyz-dev-app-tg/0123456789abcdef"
  }
}

mock_resource "aws_launch_template" {
  defaults = {
    id             = "lt-0123456789abcdef0"
    latest_version = 1
  }
}
