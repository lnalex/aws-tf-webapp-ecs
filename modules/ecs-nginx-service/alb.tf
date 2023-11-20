resource "aws_security_group" "alb_sg" {
  name_prefix = "${var.service_name}-alb-sg"
  description = "Service ALB security group for ${var.service_name}"
  ingress = [
    {
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      to_port          = 80
      from_port        = 80
      self             = false
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      description      = "Allow HTTP inbound from internet"
    },
    {
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      to_port          = 443
      from_port        = 443
      self             = false
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      description      = "Allow HTTPS inbound from internet"
    }
  ]
  # Allow all egress
  egress = [
    {
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      description      = "Allow all egress traffic"
      from_port        = 0
      to_port          = 0
      self             = false
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
    }
  ]
  vpc_id = var.vpc_id
}


# Access log bucket
module "encrypted_bucket" {
  source      = "../s3-bucket"
  bucket_name = "${var.service_name}-alb-logs"
}

resource "aws_s3_bucket_policy" "access_logs_policy" {
  bucket = module.encrypted_bucket.bucket.bucket
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.elb_log_accounts[data.aws_region.current.name]}:root"
        }
        Action = "s3:PutObject"
        Resource = "${module.encrypted_bucket.bucket.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
      }
    ]
  })
}

# ALB fronting the application
resource "aws_lb" "app_load_balancer" {
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.public_subnet_ids

  # Usually a good idea for prod, disabled here for testing reasons
  enable_deletion_protection = false

  access_logs {
    bucket  = module.encrypted_bucket.bucket.bucket
    enabled = true
  }
  depends_on = [ aws_s3_bucket_policy.access_logs_policy ]
}

# Target group
resource "aws_lb_target_group" "app_tg" {
  port        = var.task_container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
}

# Listeners
resource "aws_lb_listener" "app_http_listener" {
  load_balancer_arn = aws_lb.app_load_balancer.arn
  port              = 80
  protocol          = "HTTP"
  # Send everything to HTTPS listener
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "app_https_listener" {
  load_balancer_arn = aws_lb.app_load_balancer.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = module.acm-cert.acm_certificate.arn
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "There's nothing here!"
      status_code  = "503"
    }
  }
}

resource "aws_lb_listener_rule" "app_fw_rule" {
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
    order = 1
  }
  listener_arn = aws_lb_listener.app_https_listener.arn
  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}

module "acm-cert" {
  source = "../acm-certificate"
  hosted_zone_id = var.cert_config.hosted_zone_id
  domain_name = var.cert_config.domain_name
  providers = {
    aws.deploy = aws
    aws.hosted_zone = aws.hosted_zone
  }
}

resource "aws_route53_record" "alb_record" { 
  name = var.cert_config.domain_name
  zone_id = var.cert_config.hosted_zone_id
  type = "A"
  alias {
    name = aws_lb.app_load_balancer.dns_name
    zone_id = aws_lb.app_load_balancer.zone_id
    evaluate_target_health = true
  }
  provider = aws.hosted_zone
}