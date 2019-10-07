resource "aws_db_subnet_group" "bosh_rds" {
  name        = "${var.env}-bosh"
  description = "Subnet group for BOSH RDS"
  subnet_ids  = ["${split(",", var.infra_subnet_ids)}"]

  tags {
    Name = "${var.env}-bosh-rds"
  }
}

resource "aws_security_group" "bosh_rds" {
  name        = "${var.env}-bosh-rds"
  description = "BOSH RDS security group"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port = 5432
    to_port   = 5432
    protocol  = "tcp"

    security_groups = [
      "${aws_security_group.bosh.id}",
    ]
  }

  tags {
    Name = "${var.env}-bosh-rds"
  }
}

resource "aws_db_parameter_group" "bosh_pg_9_5" {
  name        = "${var.env}-pg95-bosh"
  family      = "postgres9.5"
  description = "RDS Postgres 9.5 default parameter group"
}

resource "aws_db_parameter_group" "bosh_pg_11" {
  name        = "${var.env}-pg11-bosh"
  family      = "postgres11"
  description = "RDS Postgres 11 default parameter group"
}

resource "aws_db_instance" "bosh" {
  identifier                 = "${var.env}-bosh"
  name                       = "bosh"
  allocated_storage          = 25
  storage_type               = "gp2"
  engine                     = "postgres"
  engine_version             = "11.1"
  instance_class             = "db.t2.small"
  username                   = "dbadmin"
  password                   = "${var.secrets_bosh_postgres_password}"
  db_subnet_group_name       = "${aws_db_subnet_group.bosh_rds.name}"
  parameter_group_name       = "${aws_db_parameter_group.bosh_pg_11.id}"
  backup_window              = "01:00-02:00"
  maintenance_window         = "${var.bosh_db_maintenance_window}"
  multi_az                   = "${var.bosh_db_multi_az}"
  backup_retention_period    = "${var.bosh_db_backup_retention_period}"
  final_snapshot_identifier  = "${var.env}-bosh-rds-final-snapshot"
  skip_final_snapshot        = "${var.bosh_db_skip_final_snapshot}"
  auto_minor_version_upgrade = true

  allow_major_version_upgrade = true
  apply_immediately           = true

  vpc_security_group_ids = ["${aws_security_group.bosh_rds.id}"]

  tags {
    Name       = "${var.env}-bosh"
    deploy_env = "${var.env}"
  }
}
