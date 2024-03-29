variable "secrets_bosh_postgres_password" {
  description = "Super User password for bosh database"
}

variable "bosh_db_multi_az" {
  description = "BOSH database multi availabiliy zones"
  default     = "false"
}

variable "bosh_db_backup_retention_period" {
  description = "BOSH database backup retention period"
  default     = "0"
}

variable "bosh_db_skip_final_snapshot" {
  description = "Whether to skip final RDS snapshot (just before destroy). Differs per environment."
  default     = "true"
}

variable "bosh_db_maintenance_window" {
  description = "The window during which updates to the Bosh database instance can occur."
}

variable "bosh_db_instance_class" {
  description = "Instance class for the BOSH RDS database."
  default     = "db.t3.small"
}

variable "bosh_az" {
  description = "A zone used to provision bosh"
}

variable "system_dns_zone_id" {
  description = "Amazon Route53 DNS zone identifier for the system components. Different per account."
}

variable "system_dns_zone_name" {
  description = "Amazon Route53 DNS zone name for the provisioned environment."
}

variable "bosh_fqdn" {
  description = "DNS record pointing to BOSH internal IP"
}

variable "bosh_fqdn_external" {
  description = "DNS record pointing to BOSH external IP"
}

variable "bosh_rds_storage_gb" {
  description = "Storage in GB allocated to BOSH RDS"
  default     = 25
}

variable "cloudwatch_log_retention_period" {
  description = "how long cloudwatch logs should be retained for (in days). Default 18 months"
  default     = 545
}

variable "csls_kinesis_destination_arn" {
  description = "The destination arn for Cyber Security's CSLS"
  type        = string
}

