locals {
  destination_arn = "${replace(var.csls_kinesis_destination_arn, "REGION", var.region)}"
  bosh_log_groups      = "${formatlist("%s_%s", var.bosh_log_groups_to_ship_to_csls, var.env)}"
  concourse_log_groups      = "${formatlist("%s_%s", var.concourse_log_groups_to_ship_to_csls, var.env)}"
}

resource "aws_cloudwatch_log_subscription_filter" "ship_bosh_logs_to_cyber" {
  count           = "${length(local.bosh_log_groups)}"
  name            = "${element(local.bosh_log_groups, count.index)}"
  log_group_name  = "${element(local.bosh_log_groups, count.index)}"
  destination_arn = "${local.destination_arn}"
  filter_pattern  = ""                                          # Matches all events
  distribution    = "Random"
}

resource "aws_cloudwatch_log_subscription_filter" "ship_concourse_logs_to_cyber" {
  count           = "${length(local.concourse_log_groups)}"
  name            = "${element(local.concourse_log_groups, count.index)}"
  log_group_name  = "${element(local.concourse_log_groups, count.index)}"
  destination_arn = "${local.destination_arn}"
  filter_pattern  = ""                                          # Matches all events
  distribution    = "Random"
}
