# Diagrama de Caso de Uso — Bastión EC2 / Clúster ECS

```mermaid
flowchart TD
    %% Actores
    Admin(["👤 Administrador\n(Admin CIDR)"])
    SSM(["☁️ AWS Systems Manager\n(SSM Service)"])
    Dev(["👤 Desarrollador\n(AWS Console / CLI)"])

    %% Límite del sistema
    subgraph SYS["Sistema de Gestión ECS"]

        subgraph BASTION["🖥️ EC2 Bastión  •  ec2_sg"]
            UC1["Conectar vía SSH\n(puerto 22)"]
            UC2["Conectar vía SSM\nSession Manager"]
            UC3["Asumir IAM Role\nec2-bastion-role"]
        end

        subgraph IAM["🔐 Capa IAM"]
            UC4["Autenticar con\nAmazonECS_FullAccess"]
            UC5["Autenticar con\nAmazonSSMManagedInstanceCore"]
        end

        subgraph ECS["📦 Clúster ECS  •  ecs_sg"]
            UC6["Listar Servicios ECS"]
            UC7["Listar Tareas ECS"]
            UC8["Actualizar Servicio ECS"]
            UC9["Inspeccionar Logs\nde Contenedor"]
        end

    end

    %% Relaciones de actores
    Admin -->|"SSH :22\nrestringido por CIDR"| UC1
    SSM   -->|"HTTPS saliente\n(egress all)"| UC2

    %% Flujo interno bastión → IAM
    UC1 --> UC3
    UC2 --> UC3
    UC3 --> UC4
    UC3 --> UC5

    %% Bastión → ECS (solo por SG reference)
    UC4 -->|"ingress :80\nsolo desde ec2_sg"| UC6
    UC4 --> UC7
    UC4 --> UC8
    UC4 --> UC9

    %% Desarrollador usa Console/CLI para observar
    Dev -->|"aws ecs describe-*"| UC6
    Dev -->|"aws ecs update-service"| UC8

    %% Estilos
    classDef actor    fill:#dbeafe,stroke:#3b82f6,color:#1e3a5f,rx:50
    classDef usecase  fill:#f0fdf4,stroke:#22c55e,color:#14532d
    classDef iam      fill:#fef9c3,stroke:#eab308,color:#713f12
    classDef ecs      fill:#fdf4ff,stroke:#a855f7,color:#3b0764

    class Admin,SSM,Dev actor
    class UC1,UC2,UC3 usecase
    class UC4,UC5 iam
    class UC6,UC7,UC8,UC9 ecs
```

## Actores

| Actor | Rol |
|---|---|
| **Administrador** | Accede al bastión vía SSH desde un CIDR corporativo restringido |
| **AWS SSM Service** | Establece sesiones seguras sin necesidad de puerto 22 expuesto |
| **Desarrollador** | Interactúa con ECS directamente via AWS CLI / Console usando el bastión como proxy de red |

## Casos de Uso

| ID | Caso de Uso | Actor Principal | Precondición |
|---|---|---|---|
| UC1 | Conectar vía SSH | Administrador | IP en `allowed_ssh_cidr` |
| UC2 | Conectar vía SSM Session Manager | SSM Service | Instancia registrada en SSM |
| UC3 | Asumir IAM Role | EC2 Bastión | Instance Profile asociado |
| UC4 | Autenticar con ECS Full Access | IAM Role | `AmazonECS_FullAccess` adjunta |
| UC5 | Autenticar con SSM Core | IAM Role | `AmazonSSMManagedInstanceCore` adjunta |
| UC6 | Listar Servicios ECS | Bastión / Dev | Ingress :80 permitido por `ecs_sg` |
| UC7 | Listar Tareas ECS | Bastión / Dev | Igual que UC6 |
| UC8 | Actualizar Servicio ECS | Bastión / Dev | Igual que UC6 |
| UC9 | Inspeccionar Logs de Contenedor | Bastión | Igual que UC6 |
```
