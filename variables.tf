
variable "region" {
  description = "Target AWS region to deploy to"
  type        = string
  default     = "ap-southeast-2"
}

variable "network_config" {
    description = "VPC network configuration"
    type = object({
      cidr_range = string
      az_list = list(string)
      public_subnet_cidrs = list(string)
      private_subnet_cidrs = list(string)
    })
}

variable "image" {
  description = "application container image URI"
  type        = string
}

variable "task_scaling_config" {
  description = "Task scaling configuration"
  type = object({
    min = number
    max = number
    target_utilization = number
  })
}

variable "compute_scaling_config" {
  description = "Compute scaling configuration"
  type = object({
    min = number
    max = number
    target_utilization = number
    instance_types = list(string)
  })
}

variable "app_container_config" {
  description = "Application container/task configuration"
  type = object({
    container_port = number
    cpu_requests = number
    mem_requests = number
  })
}

variable "container_instance_ami" {
  description = "ECS container instance AMI ID"
  type = string
}

variable "cert_config" {
  description = "ACM certificate config"
  type = object({
    domain_name = string
    hosted_zone_id = string
    route53_role = string
  })
}

variable "deploy_role_arn" {
  description = "IAM role ARN to assume for deploys"
  type = string
}