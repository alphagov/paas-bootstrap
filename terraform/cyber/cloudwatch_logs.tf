locals {
  destination_arn = "${replace(var.csls_kinesis_destination_arn, "REGION", var.region)}"
  bosh_log_groups = "${formatlist("%s_%s", var.bosh_log_groups_to_ship_to_csls, var.env)}"
}

resource "aws_cloudwatch_log_group" "auth_logs" {
  name              = "auth_logs_${var.env}"
  retention_in_days = "${var.cloudwatch_log_retention_period}"
}

resource "aws_cloudwatch_log_subscription_filter" "auth_logs_to_csls" {
  name            = "auth-logs-to-csls-${var.env}"
  log_group_name  = "${aws_cloudwatch_log_group.auth_logs.name}"
  destination_arn = "${local.destination_arn}"
  filter_pattern  = ""                                           # Matches all events
  distribution    = "Random"
}
