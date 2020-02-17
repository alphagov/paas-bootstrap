locals {
  log_groups = "${formatlist("%s_%s", var.concourse_log_groups_to_ship_to_csls, var.env)}"
}

resource "aws_cloudwatch_log_group" "concourse_vm" {
  count             = "${length(local.log_groups)}"
  name              = "${element(local.log_groups, count.index)}"
  retention_in_days = "${var.cloudwatch_log_retention_period}"
}
