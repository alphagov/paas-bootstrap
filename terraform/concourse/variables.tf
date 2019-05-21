variable "system_dns_zone_id" {
  description = "Amazon Route53 DNS zone identifier for the system components. Different per account."
}

variable "system_dns_zone_name" {
  description = "Amazon Route53 DNS zone name for the provisioned environment."
}

variable "concourse_hostname" {
  description = "Concourse hostname (unqualified, not including system_dns_zone_name)"
}

variable "git_rsa_id_pub" {
  description = "Public SSH key for the git user"
}

variable "concourse_db_maintenance_window" {
  description = "The window during which updates to the Concourse database instance can occur."
}

variable "concourse_db_multi_az" {
  description = "Concourse database multi availabiliy zones"
  default     = "false"
}

variable "concourse_db_backup_retention_period" {
  description = "BOSH database backup retention period"
  default     = "0"
}

variable "concourse_db_skip_final_snapshot" {
  description = "Whether to skip final RDS snapshot (just before destroy). Differs per environment."
  default     = "true"
}
