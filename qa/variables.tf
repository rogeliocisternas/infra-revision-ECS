variable "vpc_id" {
  description = "ID de la VPC existente donde se desplegará la infraestructura"
  type        = string
}

variable "subnet_id" {
  description = "ID de la subred compartida (debe pertenecer a la VPC indicada)"
  type        = string
}

variable "ami_id" {
  description = "AMI de Amazon Linux para la instancia bastión EC2"
  type        = string
}

variable "instance_type" {
  description = "Tipo de instancia EC2"
  type        = string
  default     = "t2.micro"
}

variable "allowed_ssh_cidr" {
  description = "Bloque CIDR administrativo autorizado para acceso SSH (puerto 22)"
  type        = string
}

variable "project_name" {
  description = "Nombre del proyecto objeto de análisis (usado en tags)"
  type        = string
}

variable "connection_test" {
  description = "Descripción o identificador de la prueba de conectividad (usado en tags)"
  type        = string
}
