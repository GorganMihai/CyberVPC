terraform {
  required_providers {
      aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

#   eu-west-1a    eu-west-1b

resource "aws_vpc" "cyber-vpc2" {
  cidr_block = "10.10.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "cyber-vpc2"
  }
}

resource "aws_subnet" "subnet2_a" {
  vpc_id            = aws_vpc.cyber-vpc2.id
  cidr_block        = "10.10.1.0/24"
  availability_zone = "${var.region}a"
  map_public_ip_on_launch = false

  tags = {
    Name = "subnet2-a"
  }
}

resource "aws_subnet" "subnet2_b" {
  vpc_id            = aws_vpc.cyber-vpc2.id
  cidr_block        = "10.10.2.0/24"
  availability_zone = "${var.region}b"
  map_public_ip_on_launch = false

  tags = {
    Name = "subnet2-b"
  }
}

resource "aws_security_group" "mutual-SSH-2" {
  name        = "mutual-SSH-2"
  description = "Allow mutual SSH from Subnet_A and Subnet_B"
  vpc_id      = aws_vpc.cyber-vpc2.id

  ingress {
    description = "SSH Subnet_A"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.10.1.0/24"]
  }

  ingress {
    description = "SSH Subnet_B"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.10.2.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mutual-SSH-2"
  }
}

# SSH Key Generation
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "main" {
  key_name   = "cyber-key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

resource "local_file" "private_key" {
  content              = tls_private_key.ssh_key.private_key_pem
  filename             = "${path.module}/cyber-key.pem"
  file_permission      = "0600"
}

# Latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 Instance in Subnet A
resource "aws_instance" "ec2_NodeA" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.subnet2_a.id
  vpc_security_group_ids      = [aws_security_group.mutual-SSH-2.id]
  key_name                    = aws_key_pair.main.key_name
  associate_public_ip_address = false

  tags = {
    Name = "ec2_NodeA"
  }

  user_data = <<EOF
#!/bin/bash

cat <<CONFIG > /home/ec2-user/.ssh/config
Host nodeB
  HostName ${aws_instance.ec2_NodeB.private_ip}
  User ec2-user
  IdentityFile /home/ec2-user/cyber-key.pem
CONFIG

chown ec2-user:ec2-user /home/ec2-user/.ssh/config
chmod 600 /home/ec2-user/.ssh/config

cat > /home/ec2-user/cyber-key.pem <<KEY
${tls_private_key.ssh_key.private_key_pem}
KEY

chown ec2-user:ec2-user /home/ec2-user/cyber-key.pem
chmod 600 /home/ec2-user/cyber-key.pem
EOF  
}

# EC2 Instance in Subnet B
resource "aws_instance" "ec2_NodeB" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.subnet2_b.id
  vpc_security_group_ids      = [aws_security_group.mutual-SSH-2.id]
  key_name                    = aws_key_pair.main.key_name
  associate_public_ip_address = false

  tags = {
    Name = "ec2_NodeB"
  }
  
  user_data = <<EOF
#!/bin/bash

cat <<CONFIG > /home/ec2-user/.ssh/config
Host nodeA
  HostName 10.10.1.209
  User ec2-user
  IdentityFile /home/ec2-user/cyber-key.pem
CONFIG

chown ec2-user:ec2-user /home/ec2-user/.ssh/config
chmod 600 /home/ec2-user/.ssh/config

cat > /home/ec2-user/cyber-key.pem <<KEY
${tls_private_key.ssh_key.private_key_pem}
KEY

chown ec2-user:ec2-user /home/ec2-user/cyber-key.pem
chmod 600 /home/ec2-user/cyber-key.pem
EOF  

}

resource "aws_ec2_instance_connect_endpoint" "Endpoint-A2" {
  subnet_id          = aws_subnet.subnet2_a.id
  security_group_ids  = [aws_security_group.mutual-SSH-2.id]
  preserve_client_ip  = false
  tags = {
    Name = "Endpoint-A2"
  }
}


terraform {
  backend "s3" {
    bucket         = "cyberbucket25"                   # S3 bucket name
    key            = "episode2/terraform.tfstate"      # path inside the bucket
    region         = "eu-west-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
