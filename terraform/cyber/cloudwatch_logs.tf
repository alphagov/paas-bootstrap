locals {
  destination_arn = "${replace(var.csls_kinesis_destination_arn, "REGION", var.region)}"
  log_groups      = "${formatlist("%s_%s", var.log_groups_to_ship_to_csls, var.env)}"
}

resource "aws_cloudwatch_log_subscription_filter" "ship_logs_to_cyber" {
  count           = "${length(local.log_groups)}"
  name            = "${element(local.log_groups, count.index)}"
  log_group_name  = "${element(local.log_groups, count.index)}"
  destination_arn = "${local.destination_arn}"
  filter_pattern  = ""                                          # Matches all events
  distribution    = "Random"
}
