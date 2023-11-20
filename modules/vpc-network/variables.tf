variable "vpc_cidr_range" {
  type = string
  description = "CIDR range for the VPC"
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  type = list(string)
  description = "AZs to provision subnets for"
}

variable "public_subnet_cidr_ranges" {
  type = list(string)
  description = "CIDR ranges for each public subnet"
}

variable "private_subnet_cidr_ranges" {
  type = list(string)
  description = "CIDR ranges for each private subnet"
}

variable "stage" {
    description = "environment"
    type = string
}
