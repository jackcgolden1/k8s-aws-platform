terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  owners = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

resource "aws_security_group" "ssh" {
  name        = "k8s-mine-ssh"
  description = "Allow SSH from my IP"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "HTTP from my IP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "Node-to-node traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "admin" {
  key_name   = "k8s-mine-key"
  public_key = file(pathexpand("~/.ssh/id_ed25519.pub"))
}

resource "aws_instance" "server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.public.id
  key_name               = aws_key_pair.admin.key_name
  vpc_security_group_ids = [aws_security_group.ssh.id]
  iam_instance_profile   = aws_iam_instance_profile.node.name # NEW

  user_data = templatefile("${path.module}/cloud-init/server.sh.tftpl", {
    k3s_token    = random_password.k3s_token.result
    ecr_registry = split("/", aws_ecr_repository.api.repository_url)[0] # NEW
  })
  user_data_replace_on_change = true

  tags = {
    Name = "k8s-mine-server"
  }
}

resource "aws_instance" "agent" {
  count = 2

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.public.id
  key_name               = aws_key_pair.admin.key_name
  vpc_security_group_ids = [aws_security_group.ssh.id]
  iam_instance_profile   = aws_iam_instance_profile.node.name # NEW

  user_data = templatefile("${path.module}/cloud-init/agent.sh.tftpl", {
    server_ip    = aws_instance.server.private_ip
    k3s_token    = random_password.k3s_token.result
    ecr_registry = split("/", aws_ecr_repository.api.repository_url)[0] # NEW
  })
  user_data_replace_on_change = true

  tags = {
    Name = "k8s-mine-agent-${count.index + 1}"
  }
}

resource "random_password" "k3s_token" {
  length  = 32
  special = false
}