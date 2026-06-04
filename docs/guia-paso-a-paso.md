# Guía Paso a Paso — Bastión EC2 para Gestión de Clúster ECS

> **Propósito:** Desplegar una instancia EC2 bastión en AWS para conectarse y administrar un clúster ECS existente, con acceso SSH y SSM Session Manager, usando Terraform como herramienta de IaC.

---

## Índice

1. [Prerrequisitos](#1-prerrequisitos)
2. [Estructura del Repositorio](#2-estructura-del-repositorio)
3. [Configuración de Credenciales AWS](#3-configuración-de-credenciales-aws)
4. [Preparar Variables por Entorno](#4-preparar-variables-por-entorno)
5. [Inicializar Terraform](#5-inicializar-terraform)
6. [Validar la Configuración](#6-validar-la-configuración)
7. [Revisar el Plan de Ejecución](#7-revisar-el-plan-de-ejecución)
8. [Aplicar la Infraestructura](#8-aplicar-la-infraestructura)
9. [Conectarse al Bastión](#9-conectarse-al-bastión)
10. [Instalar Session Manager Plugin en el Bastión](#10-instalar-session-manager-plugin-en-el-bastión)
11. [Ejecutar Comandos en Contenedores ECS](#11-ejecutar-comandos-en-contenedores-ecs)
12. [Verificar Recursos Desplegados](#12-verificar-recursos-desplegados)
13. [Destruir la Infraestructura](#13-destruir-la-infraestructura)
14. [Troubleshooting](#14-troubleshooting)

---

## 1. Prerrequisitos

Antes de comenzar, asegúrate de tener instaladas las siguientes herramientas:

| Herramienta | Versión mínima | Verificación |
|---|---|---|
| [Terraform](https://developer.hashicorp.com/terraform/install) | >= 1.5 | `terraform -version` |
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) | >= 2.x | `aws --version` |
| [Session Manager Plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) | latest | `session-manager-plugin --version` |
| [Git](https://git-scm.com/) | >= 2.x | `git --version` |

### Instalar Session Manager Plugin (macOS)

```bash
brew install session-manager-plugin
```

### Permisos IAM necesarios en tu usuario/rol de AWS

Tu usuario de AWS debe tener permisos para crear:
- `ec2:*` (instancias, security groups)
- `iam:CreateRole`, `iam:AttachRolePolicy`, `iam:CreateInstanceProfile`
- `ssm:StartSession` (para conectarse al bastión vía SSM)

---

## 2. Estructura del Repositorio

```
infra-revision-ECS/
├── qa/                        # Entorno de pruebas
│   ├── main.tf                # Provider AWS + recurso aws_instance
│   ├── variables.tf           # Declaración de variables
│   ├── iam.tf                 # IAM Role, políticas e Instance Profile
│   ├── security_groups.tf     # SG del bastión EC2 y del clúster ECS
│   └── outputs.tf             # IPs, IDs de SGs, ARN del rol
│
├── prod/                      # Entorno de producción
│   ├── main.tf
│   ├── variables.tf
│   ├── iam.tf
│   ├── security_groups.tf
│   └── outputs.tf
│
├── diagrams/
│   └── use-case.md            # Diagrama de caso de uso (Mermaid)
│
├── docs/
│   └── guia-paso-a-paso.md    # Este documento
│
├── README.md                  # Referencia general de arquitectura
└── .gitignore                 # Excluye tfstate, tfvars y .terraform/
```

> **Nota:** Cada entorno (`qa/`, `prod/`) tiene su propio estado de Terraform independiente. Nunca compartas el archivo `terraform.tfstate` entre entornos.

---

## 3. Configuración de Credenciales AWS

Terraform usa las credenciales de AWS CLI. Configúralas antes de ejecutar cualquier comando:

```bash
aws configure
```

Completa los valores solicitados:

```
AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
Default region name [None]: us-east-2
Default output format [None]: json
```

### Verificar autenticación

```bash
aws sts get-caller-identity
```

Salida esperada:

```json
{
    "UserId": "AIDACKCEVSQ6C2EXAMPLE",
    "Account": "905418315963",
    "Arn": "arn:aws:iam::905418315963:user/tu-usuario"
}
```

---

## 4. Preparar Variables por Entorno

Cada entorno necesita su propio archivo `terraform.tfvars`. Este archivo **no se sube al repositorio** (está en `.gitignore`) porque puede contener datos sensibles.

### Paso 4.1 — Obtener los valores necesarios

```bash
# Listar VPCs disponibles en tu cuenta
aws ec2 describe-vpcs --query "Vpcs[*].{ID:VpcId,CIDR:CidrBlock}" --output table

# Listar subredes de una VPC específica
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-XXXXXXXX" \
  --query "Subnets[*].{ID:SubnetId,AZ:AvailabilityZone,CIDR:CidrBlock}" \
  --output table

# Obtener la AMI más reciente de Amazon Linux 2023 en tu región
aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=al2023-ami-2023*" \
              "Name=architecture,Values=x86_64" \
  --query "sort_by(Images, &CreationDate)[-1].ImageId" \
  --output text
```

### Paso 4.2 — Crear el archivo de variables

```bash
# Para QA
cd qa/
cat > terraform.tfvars <<EOF
vpc_id           = "vpc-086f15b002cd4a308"
subnet_id        = "subnet-02489d78c15a0dc18"
ami_id           = "ami-077b630ef539aa0b5"
instance_type    = "t3.micro"
allowed_ssh_cidr = "203.0.113.0/32"   # Reemplaza con tu IP real
project_name     = "educancer-qa"
connection_test  = "prueba-conectividad-v1"
EOF
```

```bash
# Para PROD
cd ../prod/
cat > terraform.tfvars <<EOF
vpc_id           = "vpc-XXXXXXXXXXXXXXXXX"
subnet_id        = "subnet-XXXXXXXXXXXXXXXXX"
ami_id           = "ami-XXXXXXXXXXXXXXXXX"
instance_type    = "t3.micro"
allowed_ssh_cidr = "203.0.113.0/32"   # Reemplaza con tu IP real
project_name     = "educancer-prod"
connection_test  = "prueba-conectividad-prod-v1"
EOF
```

> ⚠️ **Seguridad:** Nunca pongas `0.0.0.0/0` en `allowed_ssh_cidr` en producción. Usa siempre la IP de tu VPN o red corporativa.

---

## 5. Inicializar Terraform

Desde el directorio del entorno que quieres desplegar:

```bash
cd qa/   # o cd prod/
terraform init
```

Salida esperada:

```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/aws v5.x.x...

Terraform has been successfully initialized!
```

---

## 6. Validar la Configuración

```bash
terraform validate
```

Salida esperada:

```
Success! The configuration is valid.
```

> Si aparece algún error, revisa la sección [Troubleshooting](#14-troubleshooting).

---

## 7. Revisar el Plan de Ejecución

Antes de crear cualquier recurso, revisa exactamente qué hará Terraform:

```bash
terraform plan
```

Deberías ver **7 recursos a crear**:

```
Plan: 7 to add, 0 to change, 0 to destroy.

  + aws_iam_role.ec2_bastion_role
  + aws_iam_role_policy_attachment.ecs_full_access
  + aws_iam_role_policy_attachment.ssm_core
  + aws_iam_instance_profile.ec2_bastion_profile
  + aws_security_group.ec2_sg
  + aws_security_group.ecs_sg
  + aws_instance.ec2_bastion
```

Guarda el plan en un archivo para aplicarlo de forma determinista (opcional pero recomendado):

```bash
terraform plan -out=tfplan
```

---

## 8. Aplicar la Infraestructura

```bash
terraform apply
# o si guardaste el plan:
terraform apply tfplan
```

Cuando se solicite confirmación, escribe `yes`:

```
Do you want to perform these actions?
  Enter a value: yes
```

Tiempo estimado: **~30 segundos**.

Al finalizar verás los outputs:

```
Outputs:
bastion_instance_id   = "i-0bbc467b59aa35035"
bastion_public_ip     = "3.147.103.158"
bastion_private_ip    = "19.0.36.165"
ec2_security_group_id = "sg-0e45c627771bc8ddd"
ecs_security_group_id = "sg-07b117608a0b412ab"
iam_role_arn          = "arn:aws:iam::905418315963:role/educancer-test-ec2-bastion-role"
```

---

## 9. Conectarse al Bastión

### Opción A — SSM Session Manager (recomendada)

No requiere llave `.pem` ni exposición del puerto 22:

```bash
# Obtener el ID de la instancia desde los outputs
INSTANCE_ID=$(terraform output -raw bastion_instance_id)

# Iniciar sesión
aws ssm start-session --target $INSTANCE_ID
```

> Espera 1-2 minutos después del `apply` para que el agente SSM termine de inicializarse.

### Opción B — SSH clásico

Requiere haber configurado una `key_name` en `main.tf` antes del despliegue.

```bash
PUBLIC_IP=$(terraform output -raw bastion_public_ip)
ssh -i ~/.ssh/tu-llave.pem ec2-user@$PUBLIC_IP
```

---

## 10. Instalar Session Manager Plugin en el Bastión

Una vez dentro de la sesión SSM del bastión, instala el plugin para poder ejecutar `ecs execute-command`:

```bash
# Amazon Linux 2023 (usa dnf)
sudo dnf install -y https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm

# Verificar instalación
session-manager-plugin --version
```

> **Amazon Linux 2** usa `yum` en lugar de `dnf`:
> ```bash
> sudo yum install -y https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm
> ```

---

## 11. Ejecutar Comandos en Contenedores ECS

Con el plugin instalado, ya puedes ingresar a los contenedores del clúster ECS:

### Paso 11.1 — Identificar la tarea activa

```bash
aws ecs list-tasks \
  --cluster <nombre-del-cluster> \
  --region us-east-2 \
  --query "taskArns[]" \
  --output table
```

### Paso 11.2 — Ejecutar shell en el contenedor

```bash
aws ecs execute-command \
  --cluster <nombre-del-cluster> \
  --task <task-arn-o-id> \
  --container <nombre-del-contenedor> \
  --interactive \
  --command "/bin/sh" \
  --region us-east-2
```

### Paso 11.3 — Verificar si ECS Exec está habilitado en el servicio

Si el comando anterior falla con `TargetNotConnectedException`, el servicio no tiene ECS Exec habilitado:

```bash
# Verificar el flag en la tarea
aws ecs describe-tasks \
  --cluster <nombre-del-cluster> \
  --tasks <task-id> \
  --region us-east-2 \
  --query "tasks[0].enableExecuteCommand"

# Habilitar ECS Exec en el servicio (requiere nuevo deployment)
aws ecs update-service \
  --cluster <nombre-del-cluster> \
  --service <nombre-del-servicio> \
  --enable-execute-command \
  --region us-east-2
```

---

## 12. Verificar Recursos Desplegados

Desde tu máquina local, puedes consultar el estado actual de los recursos:

```bash
# Ver todos los outputs actuales
terraform output

# Verificar la instancia en AWS
aws ec2 describe-instances \
  --instance-ids $(terraform output -raw bastion_instance_id) \
  --query "Reservations[0].Instances[0].{State:State.Name,IP:PublicIpAddress,Type:InstanceType}" \
  --output table

# Verificar que la instancia aparece en SSM
aws ssm describe-instance-information \
  --query "InstanceInformationList[?InstanceId=='$(terraform output -raw bastion_instance_id)']" \
  --output table
```

---

## 13. Destruir la Infraestructura

Cuando termines las pruebas, elimina todos los recursos para evitar costos innecesarios:

```bash
terraform destroy
```

Confirma con `yes` cuando se solicite. Esto eliminará:

- La instancia EC2 bastión
- Los dos Security Groups (`ec2_sg` y `ecs_sg`)
- El IAM Role, las políticas adjuntas y el Instance Profile

> ⚠️ **Importante:** `terraform destroy` **no elimina** el clúster ECS ni los recursos que ya existían antes del despliegue. Solo borra lo que Terraform creó en este proyecto.

---

## 14. Troubleshooting

### ❌ Error: description doesn't comply with restrictions

```
"egress.0.description" doesn't comply with restrictions
```

**Causa:** Los campos `description` de los Security Groups no aceptan caracteres no-ASCII (tildes, ñ, etc.).

**Solución:** Usar solo caracteres ASCII en todos los campos `description` de `security_groups.tf`.

---

### ❌ Error: SessionManagerPlugin is not found

```
SessionManagerPlugin is not found. Please refer to SessionManager Documentation
```

**Causa:** El plugin de Session Manager no está instalado en la instancia bastión.

**Solución:** Ejecutar dentro del bastión:

```bash
sudo dnf install -y https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm
```

---

### ❌ Error: SSM session times out / instancia no aparece en SSM

**Causa:** El agente SSM no terminó de inicializarse, o la instancia no tiene conectividad saliente.

**Solución:**

1. Esperar 2-3 minutos tras el `apply` y reintentar.
2. Verificar que el Security Group `ec2_sg` tiene el egress `0.0.0.0/0` habilitado (necesario para que el agente SSM contacte los endpoints de AWS).
3. Verificar que el IAM Role tiene `AmazonSSMManagedInstanceCore` adjunto:

```bash
aws iam list-attached-role-policies \
  --role-name $(terraform output -raw iam_role_arn | cut -d'/' -f2)
```

---

### ❌ Error: No se puede crear el IAM Role (EntityAlreadyExists)

**Causa:** Ya existe un rol con el mismo nombre de una ejecución anterior.

**Solución:**

```bash
# Importar el recurso existente al estado de Terraform
terraform import aws_iam_role.ec2_bastion_role <nombre-del-rol>
```

---

### ❌ ECS Execute Command: TargetNotConnectedException

**Causa:** La tarea ECS no tiene `enableExecuteCommand = true`.

**Solución:** Habilitar ECS Exec en el servicio y forzar un nuevo deployment:

```bash
aws ecs update-service \
  --cluster <cluster> \
  --service <servicio> \
  --enable-execute-command \
  --force-new-deployment \
  --region us-east-2
```

---

## Referencias

- [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS SSM Session Manager Plugin Install](https://docs.aws.amazon.com/systems-manager/latest/userguide/install-plugin-linux.html)
- [Amazon ECS Exec](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec.html)
- [IAM Roles for EC2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html)
