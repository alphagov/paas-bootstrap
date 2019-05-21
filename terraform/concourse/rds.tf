resource "random_string" "concourse_password" {
  length  = 64
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

resource "aws_db_parameter_group" "concourse_pg_9_5" {
  name        = "${var.env}-pg95-concourse"
  family      = "postgres9.5"
  description = "RDS Postgres 9.5 default parameter group"
}

resource "aws_db_instance" "concourse" {
  identifier                 = "${var.env}-concourse"
  name                       = "concourse"
  allocated_storage          = 5
  storage_type               = "gp2"
  engine                     = "postgres"
  engine_version             = "9.5"
  instance_class             = "db.t2.small"
  username                   = "dbadmin"
  password                   = "${random_string.concourse_password.result}"
  db_subnet_group_name       = "${aws_db_subnet_group.concourse_rds.name}"
  parameter_group_name       = "${aws_db_parameter_group.concourse_pg_9_5.id}"
  backup_window              = "01:00-02:00"
  maintenance_window         = "${var.concourse_db_maintenance_window}"
  multi_az                   = "${var.concourse_db_multi_az}"
  backup_retention_period    = "${var.concourse_db_backup_retention_period}"
  final_snapshot_identifier  = "${var.env}-concourse-rds-final-snapshot"
  skip_final_snapshot        = "${var.concourse_db_skip_final_snapshot}"
  auto_minor_version_upgrade = true

  vpc_security_group_ids = ["${aws_security_group.concourse_rds.id}"]

  tags {
    Name       = "${var.env}-concourse"
    deploy_env = "${var.env}"
  }
}
