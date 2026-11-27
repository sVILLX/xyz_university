# Valores falsos del provider AWS para `terraform test` (no se conecta a AWS).

mock_data "aws_iam_instance_profile" {
  defaults = {
    arn       = "arn:aws:iam::123456789012:instance-profile/LabInstanceProfile"
    role_name = "LabRole"
    role_arn  = "arn:aws:iam::123456789012:role/LabRole"
  }
}

mock_data "aws_iam_role" {
  defaults = {
    arn = "arn:aws:iam::123456789012:role/LabRole"
  }
}
