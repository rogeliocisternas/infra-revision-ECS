resource "aws_security_group" "ec2_sg" {
  name        = "${var.project_name}-ec2-bastion-sg"
  description = "Security Group para la instancia bastión EC2"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH administrativo restringido por CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    description = "Todo el tráfico saliente (SSM + actualizaciones)"
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
  description = "Security Group para el clúster ECS — acceso solo desde el bastión EC2"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Tráfico de servicio únicamente desde el bastión EC2"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  egress {
    description = "Todo el tráfico saliente"
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
