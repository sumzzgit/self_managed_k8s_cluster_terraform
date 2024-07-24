#---------------------- VARIABLES ---------------------------

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR Block Range"
  default     = "10.50.0.0/16"
}

//public subnets info 
variable "public-subnets" {
  description = "public subnet info"
  type = map(object({
    cidr_block = string
    az         = string
  }))
  default = {
    pub-sub-1 = {
      cidr_block = "10.50.101.0/24"
      az         = "ap-south-1a"
    }

    pub-sub-2 = {
      cidr_block = "10.50.102.0/24"
      az         = "ap-south-1b"
    }
  }
}

//private subnets info
variable "private-subnets" {
  description = "private subnets details"
  type = map(object({
    cidr_block = string
    az         = string
  }))
  default = {
    pvt-sub-1 = {
      cidr_block = "10.50.1.0/24"
      az         = "ap-south-1a"
    }

    pvt-sub-2 = {
      cidr_block = "10.50.2.0/24"
      az         = "ap-south-1b"
    }
  }
}

#--------------------- VPC CONFIGURATION ---------------------

//create VPC 
resource "aws_vpc" "k8s-vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags = {
    Name      = "k8s-vpc"
    provision = "terraform"
  }
}

//crate internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.k8s-vpc.id
  tags = {
    Name      = "k8s-vpc-igw"
    provision = "terraform"
  }
}


#-------------------- SUBNETS CONFIGURATION -------------------

// public subnets 
resource "aws_subnet" "public_subnets" {
  vpc_id                  = aws_vpc.k8s-vpc.id
  for_each                = var.public-subnets
  cidr_block              = each.value["cidr_block"]
  availability_zone       = each.value["az"]
  map_public_ip_on_launch = true
  tags = {
    Name                     = each.key
    provision                = "terraform"
    "kubernetes.io/role/elb" = "1"
  }
}

// private subnets
resource "aws_subnet" "private_subnets" {
  vpc_id            = aws_vpc.k8s-vpc.id
  for_each          = var.private-subnets
  cidr_block        = each.value["cidr_block"]
  availability_zone = each.value["az"]
  tags = {
    Name                              = each.key
    provision                         = "terraform"
    "kubernetes.io/role/internal-elb" = "1"
  }
}


#--------------------- ROUTE-TABLE AND ROUTES ----------------------------

// public route table 
resource "aws_route_table" "pub-rt-1" {
  vpc_id = aws_vpc.k8s-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

//public rt association 
resource "aws_route_table_association" "pub-rt-association" {
  for_each       = aws_subnet.public_subnets
  subnet_id      = each.value.id
  route_table_id = aws_route_table.pub-rt-1.id
}

//create private rt 
resource "aws_route_table" "pri-rt-1" {
  vpc_id = aws_vpc.k8s-vpc.id
  route {
    cidr_block = aws_vpc.k8s-vpc.cidr_block
    gateway_id = "local"
  }
  route {
    cidr_block           = "0.0.0.0/0"
    network_interface_id = aws_instance.nat-instance.primary_network_interface_id
  }
}

//private rt association
resource "aws_route_table_association" "pri-rt-association" {
  for_each       = aws_subnet.private_subnets
  subnet_id      = each.value.id
  route_table_id = aws_route_table.pri-rt-1.id
}