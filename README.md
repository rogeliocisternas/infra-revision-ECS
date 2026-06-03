# Bastión EC2 para Gestión de Clúster ECS

Infraestructura como Código (IaC) en Terraform que despliega una instancia EC2 bastión con acceso SSH y SSM para administrar un clúster ECS existente.

---

## Arquitectura

```
Internet / Admin CIDR
        │
        │ SSH :22
        ▼
┌───────────────────┐        ┌──────────────────────┐
│  EC2 Bastión      │──:80──▶│  ECS Cluster         │
│  (ec2_sg)         │        │  (ecs_sg)            │
│  + SSM Agent      │        │  ingress: solo ec2_sg│
└───────────────────┘        └──────────────────────┘
        │
        │ IAM Role
        ▼
  AmazonECS_FullAccess
  AmazonSSMManagedInstanceCore
```

---

## Estructura de Archivos

| Archivo | Descripción |
|---|---|
| [`variables.tf`](variables.tf) | Declaración de todas las variables parametrizadas |
| [`iam.tf`](iam.tf) | IAM Role, políticas adjuntas e Instance Profile |
| [`security_groups.tf`](security_groups.tf) | Security Groups del bastión EC2 y del clúster ECS |
| [`main.tf`](main.tf) | Provider AWS y recurso `aws_instance` |
| [`outputs.tf`](outputs.tf) | Outputs: IPs, IDs de SG y ARN del rol |
| [`terraform.tfvars.example`](terraform.tfvars.example) | Plantilla de variables (copiar a `terraform.tfvars`) |

---

## Variables

| Variable | Tipo | Default | Descripción |
|---|---|---|---|
| `vpc_id` | `string` | — | ID de la VPC existente |
| `subnet_id` | `string` | — | ID de la subred compartida |
| `ami_id` | `string` | — | AMI de Amazon Linux |
| `instance_type` | `string` | `t2.micro` | Tipo de instancia EC2 |
| `allowed_ssh_cidr` | `string` | — | CIDR administrativo para SSH |
| `project_name` | `string` | — | Nombre del proyecto (tag) |
| `connection_test` | `string` | — | Detalle de prueba de conectividad (tag) |

---

## Recursos IAM

El bastión recibe un **IAM Role** con las siguientes políticas administradas:

| Política | Propósito |
|---|---|
| `AmazonECS_FullAccess` | Permite al bastión administrar el clúster ECS (listar tareas, servicios, etc.) |
| `AmazonSSMManagedInstanceCore` | Habilita la comunicación con el agente SSM para sesiones sin SSH expuesto |

El rol se acopla a la instancia EC2 mediante un **IAM Instance Profile**.

---

## Reglas de Red

### Security Group — Bastión EC2 (`ec2_sg`)

| Dirección | Puerto | Protocolo | Origen/Destino | Motivo |
|---|---|---|---|---|
| Ingress | 22 | TCP | `allowed_ssh_cidr` | Acceso SSH administrativo |
| Egress | All | All | `0.0.0.0/0` | SSM Agent + actualizaciones de paquetes |

### Security Group — Clúster ECS (`ecs_sg`)

| Dirección | Puerto | Protocolo | Origen/Destino | Motivo |
|---|---|---|---|---|
| Ingress | 80 | TCP | `ec2_sg` (ID) | Solo el bastión puede alcanzar los servicios ECS |
| Egress | All | All | `0.0.0.0/0` | Tráfico saliente de contenedores |

> El ingress de `ecs_sg` referencia el **ID del Security Group** del bastión, no un CIDR, lo que garantiza que ninguna IP externa pueda alcanzar el clúster directamente.

---

## Outputs

| Output | Descripción |
|---|---|
| `bastion_instance_id` | ID de la instancia EC2 bastión |
| `bastion_public_ip` | IP pública para acceso SSH |
| `bastion_private_ip` | IP privada para comunicación interna |
| `ec2_security_group_id` | ID del SG del bastión |
| `ecs_security_group_id` | ID del SG del clúster ECS |
| `iam_role_arn` | ARN del IAM Role |

---

## Despliegue

```bash
# 1. Copiar y rellenar variables
cp terraform.tfvars.example terraform.tfvars
# editar terraform.tfvars con los valores reales

# 2. Inicializar providers
terraform init

# 3. Revisar el plan de ejecución
terraform plan

# 4. Aplicar
terraform apply
```

### Conexión vía SSM (sin SSH)

```bash
aws ssm start-session --target <bastion_instance_id>
```

### Conexión vía SSH

```bash
ssh -i <key.pem> ec2-user@<bastion_public_ip>
```

---

## Consideraciones de Seguridad

- **`allowed_ssh_cidr`** debe restringirse a la IP corporativa o VPN — nunca `0.0.0.0/0` en producción.
- Preferir **SSM Session Manager** sobre SSH para eliminar la necesidad de exponer el puerto 22.
- El archivo `terraform.tfvars` está excluido en `.gitignore` para evitar filtrar IDs de recursos.
- Para producción, reemplazar `AmazonECS_FullAccess` por una política de mínimo privilegio.
