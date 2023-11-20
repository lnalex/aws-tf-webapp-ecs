module "network" {
  source = "./modules/vpc-network"
  stage  = terraform.workspace

  vpc_cidr_range             = var.network_config.cidr_range
  availability_zones         = var.network_config.az_list
  public_subnet_cidr_ranges  = var.network_config.public_subnet_cidrs
  private_subnet_cidr_ranges = var.network_config.private_subnet_cidrs
}

module "ecs-cluster" {
  source = "./modules/ecs-cluster"
  stage  = terraform.workspace

  subnet_ids = [for subnet in module.network.private_subnets : subnet.id]
  vpc_id     = module.network.vpc_id

  cluster_name            = "app-cluster"
  compute_min_size        = var.compute_scaling_config.min
  compute_max_size        = var.compute_scaling_config.max
  compute_instance_types  = var.compute_scaling_config.instance_types
  compute_target_capacity = var.compute_scaling_config.target_utilization

  # This AMI value could be pulled dynamically with terraform, but may cause unintended container instance version upgrades
  # By design we are using manually specified value(s) to avoid accidental upgrades that have not been validated
  # See See https://docs.aws.amazon.com/AmazonECS/latest/developerguide/retrieve-ecs-optimized_AMI.html
  container_instance_ami = var.container_instance_ami
}

module "ecs-nginx-service" {
  source = "./modules/ecs-nginx-service"
  stage  = terraform.workspace

  cluster_name              = module.ecs-cluster.ecs_cluster_name
  vpc_id                    = module.network.vpc_id
  private_subnet_ids        = [for subnet in module.network.private_subnets : subnet.id]
  public_subnet_ids         = [for subnet in module.network.public_subnets : subnet.id]
  cluster_cap_provider_name = module.ecs-cluster.default_capacity_provider_name


  service_name               = "nginx-frontend"
  service_scaling_target_pct = var.task_scaling_config.target_utilization
  service_scaling_max        = var.task_scaling_config.max
  service_scaling_min        = var.task_scaling_config.min

  container_image_uri = var.image
  task_container_port = var.app_container_config.container_port
  task_cpu_requests   = var.app_container_config.cpu_requests
  task_mem_requests   = var.app_container_config.mem_requests

  cert_config = var.cert_config

  providers = {
    aws             = aws
    aws.hosted_zone = aws.hosted_zone
  }
}

