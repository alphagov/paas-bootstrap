variable "aws_account" {
  description = "the AWS account being deployed to"
}

variable "env" {
  description = "Environment name"
}

variable "region" {
  description = "AWS region"
}

variable "vpc_cidr" {
  description = "CIDR for VPC"
  default     = "10.0.0.0/16"
}

variable "vpc_id" {
  description = "id of VPC created in main 'vpc' terraform"
  default     = ""
}

variable "zones" {
  description = "AWS availability zones"
  type        = map(string)
}

variable "zone_index" {
  description = "AWS availability zone indices"
  type        = map(string)
}

variable "zone_labels" {
  description = "AWS availability zone labels as used in BOSH manifests (z1-z3)"
  type        = map(string)
}

variable "zone_count" {
  description = "Number of zones to use"
}

variable "infra_cidrs" {
  description = "CIDR for infrastructure subnet indexed by AZ"

  default = {
    zone0 = "10.0.0.0/24"
    zone1 = "10.0.1.0/24"
    zone2 = "10.0.2.0/24"
  }
}

variable "infra_gws" {
  description = "GW per CIDR"

  default = {
    "10.0.0.0/24" = "10.0.0.1"
    "10.0.1.0/24" = "10.0.1.1"
    "10.0.2.0/24" = "10.0.2.1"
  }
}

variable "microbosh_ips" {
  description = "MicroBOSH IPs per zone"
  type        = map(string)
}

variable "infra_subnet_ids" {
  description = "A comma separated list of infrastructure subnets"
  default     = ""
}

variable "set_concourse_egress_cidrs" {
  description = "Allow or restrict public egress IP address of concourse workers"
  type        = bool
  default     = false
}

variable "microbosh_static_private_ip" {
  description = "Microbosh internal IP"
  default     = "10.0.0.6"
}

/* Operators will mainly be from the office. See https://sites.google.com/a/digital.cabinet-office.gov.uk/gds-internal-it/news/aviationhouse-sourceipaddresses for details. */
variable "admin_cidrs" {
  description = "CSV of CIDR addresses with access to operator/admin endpoints"

  default = [
    "213.86.153.211/32", # New BYOD VPN IP
    "213.86.153.212/32",
    "213.86.153.213/32",
    "213.86.153.214/32",
    "213.86.153.231/32", # New BYOD VPN IP
    "213.86.153.235/32",
    "213.86.153.236/32",
    "213.86.153.237/32",
    "51.149.8.0/25",     # New DR VPN
    "51.149.8.128/29",   # New DR BYOD VPN
    "90.155.48.192/26",  # ITHC 2023
    "81.2.127.144/28",   # ITHC 2023
    "81.187.169.170/32", # ITHC 2023
    "88.97.60.11/32",    # ITHC 2023
    "3.10.4.97/32",      # ITHC 2023
    "51.104.217.191/32", # ITHC 2023
  ]
}

/* See https://docs.aws.amazon.com/elasticloadbalancing/latest/classic/elb-security-policy-table.html */
variable "default_classic_load_balancer_security_policy" {
  description = "Which Security policy to use for classic load balancers. This controls things like available SSL protocols/ciphers."
  default     = "ELBSecurityPolicy-TLS-1-2-2017-01"
}

variable "assets_prefix" {
  description = "Prefix for global assests like S3 buckets"
  default     = "gds-paas"
}

variable "bosh_log_groups_to_ship_to_csls" {
  description = "The names of the Bosh log groups to ship to CSLS, without the _env suffix"
  type        = list(string)

  default = [
    "bosh_d_audit",
    "bosh_d_audit_worker",
    "bosh_d_auth",
    "bosh_d_credhub_security_events",
    "bosh_d_kauditd",
    "bosh_d_uaa_events",
    "concourse_d_web_events",
  ]
}

variable "aws_vpc_endpoint_cidrs_per_zone" {
  description = "CIDR for AWS VPC endpoint subnets indexed by AZ"

  default = {
    zone0 = "10.0.79.0/28"
    zone1 = "10.0.79.16/28"
    zone2 = "10.0.79.32/28"
  }
}

variable "user_static_cidrs" {
  description = "user static cidrs populated with values from paas-trusted-people"
  default     = []
}
