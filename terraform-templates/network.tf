
# Creating the vpc for master
resource "aws_vpc" "vpc_jenkins_master" {
  provider             = aws.region-master
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "master-vpc-jenkins"
  }
}


# Creating the vpc for worker
resource "aws_vpc" "vpc_jenkins_worker" {
  provider             = aws.region-worker
  cidr_block           = "192.168.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "worker-vpc-jenkins"
  }
}

# Create a VPC peering from master to worker
resource "aws_vpc_peering_connection" "master-worker-peering" {
  provider    = aws.region-master
  peer_vpc_id = aws_vpc.vpc_jenkins_worker.id
  vpc_id      = aws_vpc.vpc_jenkins_master.id
  peer_region = var.region-worker
}

# Accepting the peer connection in worker region
resource "aws_vpc_peering_connection_accepter" "master-worker-peering-accepter" {
  provider                  = aws.region-worker
  vpc_peering_connection_id = aws_vpc_peering_connection.master-worker-peering.id
  auto_accept               = true
}

# Creating the internet gateway in master region
resource "aws_internet_gateway" "igw_master" {
  provider = aws.region-master
  vpc_id   = aws_vpc.vpc_jenkins_master.id
}

# getting available az in mastr region
data "aws_availability_zones" "azs" {
  provider = aws.region-master
  state    = "available"
}

# creating subnet 1 in master region
resource "aws_subnet" "subet-1-master" {
  provider          = aws.region-master
  cidr_block        = var.subet-1-master
  vpc_id            = aws_vpc.vpc_jenkins_master.id
  availability_zone = element(data.aws_availability_zones.azs.names, 0)
}

# creating subnet 2 in master region
resource "aws_subnet" "subet-2-master" {
  provider          = aws.region-master
  cidr_block        = var.subet-2-master
  vpc_id            = aws_vpc.vpc_jenkins_master.id
  availability_zone = element(data.aws_availability_zones.azs.names, 1)
}

# creating route table for jenkins master
resource "aws_route_table" "rt_jenkins_master" {
  vpc_id   = aws_vpc.vpc_jenkins_master
  provider = aws.region-master
  route {
    cidr_block = var.all_traffic
    gateway_id = aws_internet_gateway.igw_master
  }
  route {
    cidr_block                = var.subet-1-worker
    vpc_peering_connection_id = aws_vpc_peering_connection_accepter.master-worker-peering-accepter.id
  }
  lifecycle {
    ignore_changes = all
  }

  tags = {
    Name = "master-region-rt"
  }
}

# createing main route table association for master
resource "aws_main_route_table_association" "rta_jenkins_master" {
  route_table_id = aws_route_table.rt_jenkins_master.id
  provider       = aws.region-master
  vpc_id         = aws_vpc.vpc_jenkins_master.id
}


# Creating the internet gateway in worker region
resource "aws_internet_gateway" "igw_worker" {
  provider = aws.region-worker
  vpc_id   = aws_vpc.vpc_jenkins_worker.id
}


#Create subnet in worker region
resource "aws_subnet" "subnet_1_worker" {
  provider   = aws.region-worker
  vpc_id     = aws_vpc.vpc_jenkins_worker.id
  cidr_block = var.subet-1-worker
}


# creating route table for jenkins worker
resource "aws_route_table" "rt_jenkins_worker" {
  vpc_id   = aws_vpc.vpc_jenkins_worker.id
  provider = aws.region-worker
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_worker
  }
  route {
    cidr_block                = [var.subet-1-master, var.subet-2-master]
    vpc_peering_connection_id = aws_vpc_peering_connection_accepter.master-worker-peering-accepter.id
  }
  lifecycle {
    ignore_changes = all
  }

  tags = {
    Name = "worker-region-rt"
  }
}

# createing main route table association for worker
resource "aws_main_route_table_association" "rta_jenkins_worker" {
  route_table_id = aws_route_table.rt_jenkins_worker.id
  provider       = aws.region-worker
  vpc_id         = aws_vpc.vpc_jenkins_worker.id
}

#Create SG for allowing TCP/8080 from * and TCP/22 from your IP in master region
resource "aws_security_group" "jenkins-sg" {
  provider    = aws.region-master
  name        = "jenkins-sg"
  description = "Allow TCP/8080 & TCP/22"
  vpc_id      = aws_vpc.vpc_jenkins_master.id
  ingress {
    description = "Allow 22 from our public IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.external_ip]
  }
  ingress {
    description     = "allow traffic from LB on port 8080"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = []
  }
  ingress {
    description = "allow traffic from us-west-2"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.subet-1-worker]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.all_traffic]
  }
}


#Create SG for allowing TCP/22 from your IP in worker region
resource "aws_security_group" "jenkins-worker-sg" {
  provider = aws.region-worker

  name        = "jenkins--worker-sg"
  description = "Allow TCP/8080 & TCP/22"
  vpc_id      = aws_vpc.vpc_jenkins_worker.id
  ingress {
    description = "Allow 22 from our public IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.external_ip]
  }
  ingress {
    description = "Allow traffic from us-east-1"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.subet-1-master, var.subet-2-master]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.all_traffic]
  }
}

resource "aws_security_group" "lb-security-group" {

  provider    = aws.region-master
  name        = "Load balancer for master jenkins"
  description = "Allow 443 and traffic to Jenkins master security group"
  vpc_id      = aws_vpc.vpc_jenkins_master.id
  ingress {
    description = "Allow 443 from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.all_traffic]
  }
  ingress {
    description = "Allow 80 from anywhere for redirection"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.all_traffic]
  }

  ingress {
    description     = "Allow traffic to jenkins-sg"
    from_port       = 0
    to_port         = 0
    protocol        = "tcp"
    security_groups = [aws_security_group.jenkins-sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.all_traffic]
  }
}
