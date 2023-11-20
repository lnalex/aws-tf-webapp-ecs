terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.26.0"
      configuration_aliases = [aws, aws.hosted_zone]
    }
  }
}

# Task security group
resource "aws_security_group" "task_sg" {
  name_prefix = "${var.service_name}-task-sg"
  description = "ECS task security group for ${var.service_name}"
  ingress = [
    {
      cidr_blocks      = []
      ipv6_cidr_blocks = []
      self             = false
      prefix_list_ids  = []
      security_groups  = [aws_security_group.alb_sg.id]
      protocol         = "tcp"
      from_port        = var.task_container_port
      to_port          = var.task_container_port
      description      = "Allow TCP inbound from ALB"
    }
  ]
  # Allow all egress
  # Can lock this down but will depend upon application behaviour in real use cases
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


# IAM resources
resource "aws_iam_role" "task_role" {
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role_policy.json
  # Add application permissions as needed here
}

# CW Logs
resource "aws_cloudwatch_log_group" "app_log_group" {
  name = "ecs/${var.cluster_name}/${var.service_name}"
}

# Task definition and service
resource "aws_ecs_task_definition" "app_td" {

  family = var.service_name

  # Tune for application specific requirements
  cpu    = var.task_cpu_requests
  memory = var.task_mem_requests

  network_mode  = "awsvpc"
  task_role_arn = aws_iam_role.task_role.arn
  container_definitions = jsonencode([
    {
      name      = "app"
      image     = var.container_image_uri
      essential = true
      environment = [
        {
          name  = "stage"
          value = var.stage
        }
      ]

      portMappings = [
        {
          name          = "app-port"
          containerPort = var.task_container_port
          hostPort      = var.task_container_port
          appProtocol   = "http"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app_log_group.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "logs"
        }
      }
    }
  ])

  skip_destroy = true # Allow manual rollbacks in case of catastrophic failure
}

resource "aws_ecs_service" "nginx_service" {
  cluster = var.cluster_name
  name    = var.service_name

  desired_count = 1
  # Don't break scaling on deploy
  lifecycle {
    ignore_changes = [desired_count]
  }

  task_definition = aws_ecs_task_definition.app_td.arn

  propagate_tags = "NONE"

  health_check_grace_period_seconds = 15

  capacity_provider_strategy {
    base              = 1
    capacity_provider = var.cluster_cap_provider_name
    weight            = 100
  }

  deployment_controller {
    type = "ECS"
  }

  network_configuration {
    assign_public_ip = false
    security_groups  = [aws_security_group.task_sg.id]
    subnets          = var.private_subnet_ids
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app_tg.arn
    container_name   = "app"
    container_port   = var.task_container_port
  }

  # Use CB to rollback bad deploys
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # Service discovery/mesh through service connect
  service_connect_configuration {
    enabled = true
    service {
      client_alias {
        dns_name = var.service_name
        port = 80
      }
      port_name = "app-port"
    }
  }
}


# Service autoscaling
resource "aws_appautoscaling_target" "service_aas_target" {
  resource_id        = "service/${var.cluster_name}/${var.service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
  min_capacity       = var.service_scaling_min
  max_capacity       = var.service_scaling_max
}

resource "aws_appautoscaling_policy" "service_aas_policy" {
  name               = "${var.cluster_name}-${var.service_name}-scaling-policy"
  resource_id        = aws_appautoscaling_target.service_aas_target.resource_id
  scalable_dimension = aws_appautoscaling_target.service_aas_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.service_aas_target.service_namespace

  policy_type = "TargetTrackingScaling"
  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization" # Web servers returning static content are more likely to be CPU bound
    }
    target_value = var.service_scaling_target_pct
  }
}
