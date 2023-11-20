variable "vpc_id" {
  description = "VPC of the cluster subnets"
  type = string
}

variable "subnet_ids" {
  description = "Subnets to provision container instances into"
  type = list(string)
}

variable "cluster_name" {
  description = "Name of the ECS cluster"
  type = string
}

variable "compute_max_size" {
  description = "ASG max size for EC2 capacity provider"
  type = number
}

variable "compute_min_size" {
  description = "ASG min size for EC2 capacity provider"
  type = number
}

variable "compute_root_vol_size" {
  description = "Container instance root volume size (GB)"
  type = number
  default = 30
}

variable "compute_target_capacity" {
  description = "Target resource utilization percentage for capacity provider"
  type = number
}

variable "compute_instance_types" {
  description = "Instance types for capacity provider ASG"
  type = list(string)
}

variable "container_instance_ami" {
  description = "AMI ID for container instances"
  type = string
}

variable "stage" {
  description = "environment"
  type = string
}
