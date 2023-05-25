resource "aws_security_group" "bosh_lb" {
  name        = "${var.env}-bosh-lb"
  description = "BOSH LB security group"
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
    cidr_blocks = concat(
      var.admin_cidrs,
      var.user_static_cidrs,
    )
  }

  tags = {
    Name = "${var.env}-bosh-lb"
  }
}

resource "aws_lb" "bosh" {
  name               = "${var.env}-bosh"
  idle_timeout       = 600
  load_balancer_type = "application"

  subnets = split(",", var.infra_subnet_ids)

  security_groups = [
    aws_security_group.bosh_api_client.id,
    aws_security_group.bosh_lb.id,
  ]

  tags = {
    Name = "${var.env}-bosh-lb"
  }
}

resource "aws_lb_listener" "bosh_tls" {
  load_balancer_arn = aws_lb.bosh.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = aws_acm_certificate.bosh.arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Target not found"
      status_code  = "404"
    }
  }
}

resource "aws_lb_target_group" "bosh_uaa" {
  name        = "${var.env}-bosh-uaa"
  port        = 8443
  protocol    = "HTTPS"
  target_type = "ip"
  vpc_id      = var.vpc_id
}

resource "aws_lb_target_group_attachment" "bosh_uaa_bosh_static" {
  target_group_arn = aws_lb_target_group.bosh_uaa.arn
  target_id        = var.microbosh_static_private_ip
}

resource "aws_lb_listener_rule" "bosh_uaa" {
  listener_arn = aws_lb_listener.bosh_tls.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.bosh_uaa.arn
  }

  condition {
    host_header {
      values = ["bosh-uaa-external.${var.system_dns_zone_name}"]
    }
  }
}

resource "aws_route53_record" "bosh_uaa_external" {
  zone_id = var.system_dns_zone_id
  name    = "bosh-uaa-external.${var.system_dns_zone_name}"
  type    = "A"

  alias {
    name                   = aws_lb.bosh.dns_name
    zone_id                = aws_lb.bosh.zone_id
    evaluate_target_health = false
  }
}
