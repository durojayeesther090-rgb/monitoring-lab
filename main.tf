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

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = var.key_name
  public_key = file(pathexpand(var.public_key_path))
}

resource "aws_security_group" "monitoring_sg" {
  name        = "monitoring-sg"
  description = "SSH, Grafana, Prometheus, Node Exporter"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Prometheus"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Node Exporter (only between our own servers)"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "monitor" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.monitoring_sg.id]

  root_block_device {
    volume_size = 20
  }

  tags = {
    Name = "monitor-server"
  }
}

resource "aws_instance" "target" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.monitoring_sg.id]

  root_block_device {
    volume_size = 20
  }

  tags = {
    Name = "target-server"
  }
}

# Dynamic Ansible inventory
resource "local_file" "ansible_inventory" {
  content  = <<-EOT
    [monitor]
    ${aws_instance.monitor.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/prestashop-key ansible_ssh_common_args='-o StrictHostKeyChecking=no'

    [target]
    ${aws_instance.target.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/prestashop-key ansible_ssh_common_args='-o StrictHostKeyChecking=no'
  EOT
  filename = "${path.module}/inventory.ini"
}

# Prometheus config generated from a template, using the servers' private IPs
resource "local_file" "prometheus_config" {
  content = templatefile("${path.module}/prometheus.yml.tpl", {
    monitor_ip = aws_instance.monitor.private_ip
    target_ip  = aws_instance.target.private_ip
  })
  filename = "${path.module}/prometheus.yml"
}

resource "null_resource" "run_ansible" {
  depends_on = [local_file.ansible_inventory, local_file.prometheus_config]

  provisioner "local-exec" {
    command = <<-EOT
      sleep 60
      ansible-playbook -i inventory.ini playbook.yml
    EOT
  }
}
