data "aws_instances" "concourse_workers" {
  filter {
    name   = "tag:instance_group"
    values = ["concourse-worker", "concourse-lite"]
  }

  filter {
    name   = "tag:deploy_env"
    values = [var.env]
  }
}

resource "aws_elb" "concourse" {
  name         = "${var.env}-concourse"
  subnets      = split(",", var.infra_subnet_ids)
  idle_timeout = 600

  security_groups = [
    aws_security_group.concourse-elb.id,
    aws_security_group.concourse-elb-nocycle.id,
  ]

  health_check {
    target              = "TCP:8080"
    interval            = 5
    timeout             = 2
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  listener {
    instance_port      = 8080
    instance_protocol  = "tcp"
    lb_port            = 443
    lb_protocol        = "ssl"
    ssl_certificate_id = aws_acm_certificate_validation.system.certificate_arn
  }

  tags = {
    Name = "${var.env}-concourse-elb"
  }
}

resource "aws_lb_ssl_negotiation_policy" "concourse" {
  name          = "paas-${var.default_classic_load_balancer_security_policy}"
  load_balancer = aws_elb.concourse.id
  lb_port       = 443

  attribute {
    name  = "Reference-Security-Policy"
    value = var.default_classic_load_balancer_security_policy
  }
}

resource "aws_security_group" "concourse-elb" {
  name        = "${var.env}-concourse-elb"
  description = "Concourse ELB security group"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    cidr_blocks = compact(
      distinct(
        concat(
          var.admin_cidrs,
          ["${aws_eip.concourse.public_ip}/32"],
          var.set_concourse_egress_cidrs == false ? [] : formatlist("%s/32", data.aws_instances.concourse_workers.public_ips),
        ),
      ),
    )
  }

  tags = {
    Name = "${var.env}-concourse-elb"
  }
}

resource "aws_security_group" "concourse-elb-nocycle" {
  name        = "${var.env}-concourse-elb-nocycle"
  description = "Concourse ELB nocycle security group"
  vpc_id      = var.vpc_id

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"

    security_groups = [
      aws_security_group.concourse-worker.id,
      aws_security_group.concourse-nocycle.id,
    ]
  }

  tags = {
    Name = "${var.env}-concourse-elb-nocycle"
  }
}

resource "aws_route53_record" "concourse" {
  zone_id = var.system_dns_zone_id
  name    = "${var.concourse_hostname}.${var.system_dns_zone_name}."
  type    = "CNAME"
  ttl     = "60"
  records = [aws_elb.concourse.dns_name]
}

