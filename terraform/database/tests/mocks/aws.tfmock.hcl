mock_resource "aws_db_instance" {
  defaults = {
    address = "xyz-dev-db.abc123.us-east-1.rds.amazonaws.com"
  }
}

mock_resource "aws_secretsmanager_secret" {
  defaults = {
    arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:Mydbsecret-AbC123"
  }
}