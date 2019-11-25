resource "random_password" "concourse_rds_password" {
  length  = 40    # Max length 41 ASCII Chars
  special = false
}

resource "aws_db_subnet_group" "concourse_rds" {
  name        = "${var.env}-concourse"
  description = "Subnet group for Concourse RDS"
  subnet_ids  = ["${split(",", var.infra_subnet_ids)}"]

  tags {
    Name = "${var.env}-concourse-rds"
  }
}

resource "aws_security_group" "concourse_rds" {
  name        = "${var.env}-concourse-rds"
  description = "Concourse RDS security group"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port = 5432
    to_port   = 5432
    protocol  = "tcp"

    security_groups = [
      "${aws_security_group.concourse.id}",
    ]
  }

  tags {
    Name = "${var.env}-concourse-rds"
  }
}

resource "aws_db_parameter_group" "concourse_pg_11" {
  name        = "${var.env}-pg11-concourse"
  family      = "postgres11"
  description = "RDS Postgres 11 default parameter group"
}

resource "aws_db_instance" "concourse" {
  identifier                 = "${var.env}-concourse"
  name                       = "concourse"
  allocated_storage          = 25
  storage_type               = "gp2"
  engine                     = "postgres"
  engine_version             = "11.5"
  instance_class             = "db.t3.small"
  username                   = "concourse"
  password                   = "${random_password.concourse_rds_password.result}"
  db_subnet_group_name       = "${aws_db_subnet_group.concourse_rds.name}"
  parameter_group_name       = "${aws_db_parameter_group.concourse_pg_11.id}"
  backup_window              = "01:00-02:00"
  maintenance_window         = "${var.concourse_db_maintenance_window}"
  multi_az                   = "${var.concourse_db_multi_az}"
  backup_retention_period    = "${var.concourse_db_backup_retention_period}"
  final_snapshot_identifier  = "${var.env}-concourse-rds-final-snapshot"
  skip_final_snapshot        = "${var.concourse_db_skip_final_snapshot}"
  auto_minor_version_upgrade = true

  allow_major_version_upgrade = true
  apply_immediately           = true

  vpc_security_group_ids = ["${aws_security_group.concourse_rds.id}"]

  tags {
    Name       = "${var.env}-concourse"
    deploy_env = "${var.env}"
  }
}
