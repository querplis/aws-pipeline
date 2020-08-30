
# /21 subnet per az
locals {
  subnets = {
    "${var.region}a" = "10.0.0.0/21"
    "${var.region}b" = "10.0.8.0/21"
    "${var.region}c" = "10.0.16.0/21"
  }
}

# vpc
resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"

  # enable_dns_support   = true
  # enable_dns_hostnames = true

  tags = {
    Name = var.appname
  }
}

# create subnets 
resource "aws_subnet" "subnet" {
  count      = length(local.subnets)
  cidr_block = element(values(local.subnets), count.index)
  vpc_id     = aws_vpc.vpc.id

  # assign public ip
  map_public_ip_on_launch = true
  availability_zone       = element(keys(local.subnets), count.index)

  
  tags = {
    Name = "${element(keys(local.subnets), count.index)}"
  }
}

#gateway
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.appname}-internet-gateway"
  }
}

# routing table
resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.appname}-route-table-public"
  }
}

# default route to internet via internet gateway
resource "aws_route" "public" {
  route_table_id         =  aws_route_table.route_table.id
  destination_cidr_block =  "0.0.0.0/0"
  gateway_id             =  aws_internet_gateway.internet_gateway.id
}

# subnet assoociiations
resource "aws_route_table_association" "rta" {
  count          = length(local.subnets)
  route_table_id = aws_route_table.route_table.id
  subnet_id      = element(aws_subnet.subnet.*.id, count.index)
}
