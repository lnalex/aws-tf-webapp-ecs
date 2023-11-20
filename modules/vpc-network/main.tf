terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 5.26.0"
    }
  }
}

resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr_range
  tags = {
    Name = "app-${var.stage} VPC"
    Stage = var.stage
  }
}

# Subnets
resource "aws_subnet" "public_subnets" {
  count = length(var.availability_zones)

  vpc_id = aws_vpc.vpc.id
  cidr_block = var.public_subnet_cidr_ranges[count.index]
  availability_zone = var.availability_zones[count.index]
  map_public_ip_on_launch = true # Needed to support EKS MNG

  tags = {
    Name = "${var.availability_zones[count.index]}-public"
    Stage = var.stage
    "kubernetes.io/role/elb" = "1" # Used by EKS for ELB subnet selection
  }
}

resource "aws_subnet" "private_subnets" {
  count = length(var.availability_zones)

  vpc_id = aws_vpc.vpc.id
  cidr_block = var.private_subnet_cidr_ranges[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.availability_zones[count.index]}-private"
    Stage = var.stage
    "kubernetes.io/role/internal-elb" = "1" # Used by EKS for ELB subnet selection
  }
}

# Internet connectivity
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id # Handles attachment to VPC
  tags = {
    Name = "app-${var.stage} VPC IGW"
    Stage = var.stage
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "app-${var.stage}-public-route-table"
    Stage = var.stage
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_rt_assoc" {
  count = length(var.availability_zones)

  subnet_id = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

# Outbound internet connectivity
# One NAT GW per AZ
resource "aws_eip" "natgw_eip" {
  count = length(var.availability_zones)

  depends_on = [ aws_internet_gateway.igw ]
}

resource "aws_nat_gateway" "natgw" {
  count = length(aws_eip.natgw_eip)

  allocation_id = aws_eip.natgw_eip[count.index].id
  connectivity_type = "public"
  subnet_id = aws_subnet.public_subnets[count.index].id
  tags = {
    Name = "${var.availability_zones[count.index]}-nat-gateway"
    Stage = var.stage
  }
}

resource "aws_route_table" "private_rt" {
  count = length(var.availability_zones)

  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.availability_zones[count.index]}-private-route-table"
    Stage = var.stage
  }

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgw[count.index].id
  }
}

resource "aws_route_table_association" "private_rt_assoc" {
  count = length(var.availability_zones)

  subnet_id = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_rt[count.index].id
}