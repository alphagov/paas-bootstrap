variable "csls_kinesis_destination_arn" {
  description = "The destination arn for Cyber Security's CSLS"
  type        = string
}

variable "cloudwatch_log_retention_period" {
  description = "how long cloudwatch logs should be retained for (in days). Default 18 months"
  default     = 545
}

