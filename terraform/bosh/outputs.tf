output "bosh_subnet_id" {
  value = "${element(split(",", var.infra_subnet_ids), lookup(var.zone_index, var.bosh_az))}"
}

output "bosh_subnet_cidr" {
  value = "${lookup(var.infra_cidrs, format("zone%s", lookup(var.zone_index, var.bosh_az)))}"
}

output "bosh_default_gw" {
  value = "${lookup(var.infra_gws, lookup(var.infra_cidrs, format("zone%s", lookup(var.zone_index, var.bosh_az))))}"
}

output "microbosh_static_private_ip" {
  value = "${lookup(var.microbosh_ips, var.bosh_az)}"
}

output "bosh_security_group" {
  value = "${aws_security_group.bosh.name}"
}

output "bosh_managed_security_group" {
  value = "${aws_security_group.bosh_managed.name}"
}

output "microbosh_static_public_ip" {
  value = "${aws_eip.bosh.public_ip}"
}

output "bosh_blobstore_bucket_name" {
  value = "${aws_s3_bucket.bosh-blobstore.id}"
}

output "bosh_db_address" {
  value = "${aws_db_instance.bosh.address}"
}

output "bosh_db_port" {
  value = "${aws_db_instance.bosh.port}"
}

output "bosh_db_username" {
  value = "${aws_db_instance.bosh.username}"
}

output "bosh_db_dbname" {
  value = "${aws_db_instance.bosh.name}"
}

output "bosh_az" {
  value = "${var.bosh_az}"
}

output "bosh_az_label" {
  value = "${lookup(var.zone_labels, var.bosh_az)}"
}

output "key_pair_name" {
  value = "${aws_key_pair.env_key_pair.key_name}"
}

output "bosh_api_client_security_group" {
  value = "${aws_security_group.bosh_api_client.name}"
}

output "bosh_ssh_client_security_group" {
  value = "${aws_security_group.bosh_ssh_client.name}"
}

output "default_security_group" {
  value = "${aws_security_group.bosh_managed.name}"
}

output "bosh_security_group_id" {
  value = "${aws_security_group.bosh.id}"
}
