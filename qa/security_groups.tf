resource "aws_security_group" "ec2_sg" {
  name        = "${var.project_name}-ec2-bastion-sg"
  description = "Security Group - EC2 bastion instance"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH admin access restricted by CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    description = "All outbound traffic (SSM + package updates)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-ec2-bastion-sg"
    Project = var.project_name
  }
}

resource "aws_security_group" "ecs_sg" {
  name        = "${var.project_name}-ecs-cluster-sg"
  description = "Security Group - ECS cluster, inbound only from bastion SG"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Service traffic only from EC2 bastion SG"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-ecs-cluster-sg"
    Project = var.project_name
  }
}
