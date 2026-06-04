terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  # Configurar región via variable de entorno AWS_DEFAULT_REGION
  # o añadir: region = "us-east-1"
}

resource "aws_instance" "ec2_bastion" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_bastion_profile.name

  # Habilitar asociación de IP pública para acceso SSH externo
  associate_public_ip_address = true

  tags = {
    Name        = "${var.project_name}-bastion"
    Project     = var.project_name
    TestDetails = var.connection_test
  }
}
