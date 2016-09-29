provider "aws" {
  region = "${var.region}"

  /* Guard to prevent operating on an unintended account */
  allowed_account_ids = [
    "${lookup(var.account_ids, var.aws_account)}",
  ]
}
