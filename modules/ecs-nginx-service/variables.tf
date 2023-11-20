variable "service_name" {
  description = "ECS service name"
  type        = string
}

variable "cluster_name" {
  description = "ECS cluster name to deploy to"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID to deploy into"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnets IDs"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "container_image_uri" {
  description = "Container image URI to deploy"
  type        = string
}

variable "task_cpu_requests" {
  description = "CPU shares requested for task"
  type = number
  default = 1024
}

variable "task_mem_requests" {
  description = "Memory (MiB) requested for task"
  type = number
  default = 2048
}

variable "task_container_port" {
  description = "Container port for port mappings and security group rules"
  type = number
  default = 80
}

variable "cluster_cap_provider_name" {
  description = "Capacity provider name"
  type        = string
}

# Note that cost is still bound by capacity provider limits
variable "service_scaling_min" {
  description = "Min task count for scaling"
  type = number
  default = 1
}

variable "service_scaling_max" {
  description = "Max task count for scaling"
  type = number
}

variable "service_scaling_target_pct" {
  # Tune up or down as needed for ability to handle spikes vs cost
  # Containers are faster to launch vs EC2 instances, so it is reasonable to set this higher than capacity provider targets
  description = "Target CPU utilization %"
  type = number
}

variable "cert_config" {
  description = "ACM certificate config"
  type = object({
    domain_name = string
    hosted_zone_id = string
    route53_role = string
  })
}

variable "stage" {
  description = "environment"
  type        = string
}
