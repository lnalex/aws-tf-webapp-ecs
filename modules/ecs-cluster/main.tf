terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.26.0"
    }
  }
}

# Cluster and service discovery resources

resource "aws_service_discovery_private_dns_namespace" "sd_namespace" {
  name = var.cluster_name
  description = "ECS service connect namespace"
  vpc = var.vpc_id
}

resource "aws_ecs_cluster" "ecs_cluster" {
  name = var.cluster_name
  tags = {
    Stage = var.stage
  }

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  service_connect_defaults {
    namespace = aws_service_discovery_private_dns_namespace.sd_namespace.arn
  }
}


# Capacity provider compute resources
resource "aws_security_group" "cluster_ec2_compute_sg" {
  name_prefix = "${var.cluster_name}-container-instance-sg"
  description = "Container instance security group"
  # Allow all egress and no ingress for the host instance
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

data "aws_iam_policy_document" "ec2_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "container_instance_role" {
  name_prefix         = "${var.cluster_name}-container-instance-role"
  assume_role_policy  = data.aws_iam_policy_document.ec2_assume_role_policy.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role", "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
}

resource "aws_iam_instance_profile" "container_instance_profile" {
  name_prefix = "${var.cluster_name}-container-instance-profile"
  role        = aws_iam_role.container_instance_role.name
}

resource "aws_launch_template" "cluster_ec2_compute_lt" {

  name_prefix = "${var.cluster_name}-container-instance-compute"

  image_id = var.container_instance_ami
  iam_instance_profile {
    arn = aws_iam_instance_profile.container_instance_profile.arn
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = var.compute_root_vol_size
    }
  }

  network_interfaces {
    security_groups = [aws_security_group.cluster_ec2_compute_sg.id]
  }

  user_data = base64encode(<<EOF
#!/bin/bash -xe
echo ECS_CLUSTER=${var.cluster_name} >> /etc/ecs/ecs.config
  EOF
  )
}

resource "aws_autoscaling_group" "cluster_ec2_compute_asg" {

  name_prefix = "${var.cluster_name}-container-instance-asg"

  min_size = var.compute_min_size
  max_size = var.compute_max_size

  # Launch container instances into private subnets
  vpc_zone_identifier = var.subnet_ids

  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.cluster_ec2_compute_lt.id
        version = "$Latest"
      }

      dynamic "override" {
        for_each = toset(var.compute_instance_types)
        content {
          instance_type = override.key
        }
      }
    }
  }

  protect_from_scale_in = true

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "${var.cluster_name}-ecs-container-instance"
    propagate_at_launch = true
  }
}

# Capacity provider

resource "aws_ecs_capacity_provider" "cluster_ec2_provider" {
  name = "ec2_provider"
  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.cluster_ec2_compute_asg.arn
    managed_termination_protection = "ENABLED"
    managed_scaling {
      status          = "ENABLED"
      target_capacity = var.compute_target_capacity
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "name" {
  cluster_name       = aws_ecs_cluster.ecs_cluster.name
  capacity_providers = [aws_ecs_capacity_provider.cluster_ec2_provider.name]

  default_capacity_provider_strategy {
    base              = 1
    capacity_provider = aws_ecs_capacity_provider.cluster_ec2_provider.name
    weight            = 100
  }
}
