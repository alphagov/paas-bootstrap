resource "aws_eip" "concourse" {
  count = var.web_instances
  vpc = true
}

