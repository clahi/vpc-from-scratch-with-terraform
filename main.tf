provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "main-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "public-subnet"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "private-subnet"
  }
}

resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}


resource "aws_route_table" "public-subnet-route-table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ig.id
  }

  tags = {
    Name = "public-subnet-route-table"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public-subnet-route-table.id
}

resource "aws_route" "r" {
  gateway_id             = aws_internet_gateway.ig.id
  route_table_id         = aws_route_table.public-subnet-route-table.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_network_interface" "network-interface" {
  subnet_id   = aws_subnet.public.id
  private_ips = ["10.0.1.100"]

  security_groups = [aws_security_group.allow_ssh.id]



  tags = {
    Name = "primary_network_interface"
  }
}

resource "aws_network_interface" "network-interface_2" {
  subnet_id   = aws_subnet.public.id
  private_ips = ["10.0.1.101"]

  security_groups = [aws_security_group.allow_ssh.id]



  tags = {
    Name = "primary_network_interface"
  }
}


data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

data "aws_ami" "this" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "name"
    values = ["al2023-ami-2023*"]
  }

}

resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = tls_private_key.pk.public_key_openssh
}

resource "local_file" "ssh_key" {
  content  = tls_private_key.pk.private_key_openssh
  filename = "${aws_key_pair.deployer.key_name}.pem"
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow ssh inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "ssh from vpc"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  key_name = aws_key_pair.deployer.key_name


  network_interface {
    network_interface_id = aws_network_interface.network-interface.id
    device_index         = 0
  }



  tags = {
    Name = "Helloworld"
  }
}

resource "aws_instance" "second-server" {
  ami           = data.aws_ami.this.id
  instance_type = "t3.micro"

  key_name = aws_key_pair.deployer.key_name


  network_interface {
    network_interface_id = aws_network_interface.network-interface_2.id
    device_index         = 0
  }



  tags = {
    Name = "Helloworld"
  }
}

resource "aws_eip" "eip" {
  instance = aws_instance.web.id
  vpc      = true
}

resource "aws_eip" "eip_2" {
  instance = aws_instance.second-server.id
  vpc      = true
}
































