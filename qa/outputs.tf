output "bastion_instance_id" {
  description = "ID de la instancia EC2 bastión"
  value       = aws_instance.ec2_bastion.id
}

output "bastion_public_ip" {
  description = "IP pública de la instancia bastión (para acceso SSH)"
  value       = aws_instance.ec2_bastion.public_ip
}

output "bastion_private_ip" {
  description = "IP privada de la instancia bastión (para comunicación interna)"
  value       = aws_instance.ec2_bastion.private_ip
}

output "ec2_security_group_id" {
  description = "ID del Security Group del bastión EC2"
  value       = aws_security_group.ec2_sg.id
}

output "ecs_security_group_id" {
  description = "ID del Security Group del clúster ECS"
  value       = aws_security_group.ecs_sg.id
}

output "iam_role_arn" {
  description = "ARN del IAM Role asignado al bastión EC2"
  value       = aws_iam_role.ec2_bastion_role.arn
}
