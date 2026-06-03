# Provisionamento de LXC no Proxmox com Terraform: Guia de Estudo e Replicação

Este documento foi atualizado para refletir o estado atual da pasta `terraform/` e servir como base de estudo e replicação. A intenção continua a mesma: documentar a infraestrutura como código usada no laboratório, mas agora com a migração para o provider `bpg/proxmox`, que substituiu o antigo `Telmate/proxmox` na camada atual.

A primeira versão deste material se inspirou em referências voltadas a VMs com Cloud-Init, mas o projeto evoluiu para uma abordagem mais leve e prática para laboratórios: provisionamento de **Contêineres LXC** com autenticação via **Vault** e gerenciamento pela API do **Proxmox VE**.

---

## 1. Migração do Telmate para o BPG

O ponto mais importante desta revisão é a troca do provider. A documentação antiga citava o `Telmate/proxmox`, que foi útil para a fase inicial do projeto e para exemplos mais simples de LXC. A base atual, porém, usa `bpg/proxmox`, com recursos mais alinhados ao modelo moderno do Proxmox VE e ao estilo de configuração adotado neste repositório.

Na prática, essa mudança trouxe três ganhos principais:

1. O recurso passou a ser `proxmox_virtual_environment_container`, que representa melhor o container LXC na API atual do Proxmox.
2. A configuração de inicialização ficou mais expressiva, com blocos para CPU, memória, disco, rede, sistema operacional e usuário.
3. A autenticação com a API ficou mais direta, usando `endpoint` e `api_token`, em vez do formato antigo baseado em `pm_api_url` e `pm_api_token_secret`.

Essa evolução não é só estética. Ela facilita manutenção, melhora a legibilidade do código e reduz a distância entre o Terraform e a estrutura real do Proxmox VE.

---

## 2. Arquitetura Atual do Terraform

A base atual do diretório `terraform/` está organizada em duas camadas principais:

1. `layers/02-alunos/`, que concentra a composição da turma e o provider.
2. `modules/lxc/`, que encapsula a criação do container de forma reutilizável.

Essa separação permite escalar o laboratório sem duplicar blocos de recurso. A camada define os dados da turma; o módulo executa a criação do container.

### 2.1. Provider e Vault em `layers/02-alunos/provider.tf`

O arquivo `provider.tf` mostra a integração entre Terraform, Vault e Proxmox:

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.101.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "5.4.0"
    }
  }
}

provider "vault" {
  address         = var.vault_address
  token           = var.vault_token
  skip_tls_verify = true
}

data "vault_kv_secret_v2" "proxmox_secret" {
  mount = "senhas"
  name  = "proxmox"
}

provider "proxmox" {
  endpoint  = var.pm_api_url
  api_token = "${var.pm_api_token_id}=${data.vault_kv_secret_v2.proxmox_secret.data[\"pm_api_token_secret\"]}"
  insecure  = true
}
```

O fluxo é simples:

1. O Terraform acessa o Vault com o provider `hashicorp/vault`.
2. O segredo `proxmox` é lido no mount `senhas`.
3. O token do Proxmox é montado dinamicamente e enviado ao provider `bpg/proxmox`.

Esse desenho preserva a credencial sensível fora do código e mantém a conexão com o Proxmox parametrizada.

### 2.2. Inventário da turma em `layers/02-alunos/locals.tf`

O arquivo `locals.tf` concentra os dados de rede e os alunos da turma:

```hcl
locals {
  network_management = {
    bridge      = "vmbr0"
    gateway     = "10.0.40.1"
    dns_domain  = "infra.local"
    dns_servers = ["8.8.8.8", "8.8.4.4"]

    interfaces = [
      {
        name   = "eth0"
        bridge = "vmbr0"
      }
    ]
  }

  alunos_turma_a = {
    "aluno-01" = {
      vmid              = null
      hostname          = "aluno-01.local"
      target_node       = "testpve01"
      pool_id           = "turma-a"
      template_id       = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
      os_type           = "debian"
      cores             = 4
      memory            = 1024
      swap              = 512
      ip                = "10.0.40.201/24"
      tags              = ["IAC", "aluno", "turma-a"]
      unprivileged      = true
      nesting           = true
      startup_order     = "order=3,up=20"
      root_disk_storage = "local-zfs"
      root_disk_size    = 8
    }
  }
}
```

Na prática, o `locals` funciona como o inventário do laboratório. Ele define a rede padrão e centraliza os parâmetros de cada container, como nó de destino, template, CPU, memória, disco, IP, tags e recursos extras.

### 2.3. Orquestração da camada em `layers/02-alunos/main.tf`

A camada principal consome os dados do `locals` e instancia o módulo para cada aluno:

```hcl
module "alunos" {
  source   = "../../modules/lxc"
  for_each = local.alunos_turma_a

  vmid               = each.value.vmid
  hostname           = each.value.hostname
  target_node        = each.value.target_node
  pool_id            = each.value.pool_id
  template_id        = each.value.template_id
  os_type            = each.value.os_type
  cores              = each.value.cores
  memory             = each.value.memory
  swap               = each.value.swap
  ip                 = each.value.ip
  network_interfaces = local.network_management.interfaces
  dns_domain         = local.network_management.dns_domain
  dns_servers        = local.network_management.dns_servers
  tags               = each.value.tags
  unprivileged       = each.value.unprivileged
  nesting            = each.value.nesting
  startup_order      = each.value.startup_order
  root_disk_storage  = each.value.root_disk_storage
  root_disk_size     = each.value.root_disk_size
  network_config     = local.network_management
  admin_ssh_keys     = [data.vault_kv_secret_v2.proxmox_secret.data["ssh_public_key"]]
  root_password      = data.vault_kv_secret_v2.proxmox_secret.data["lxc_root_password"]
}
```

O `for_each` evita repetição manual. Cada entrada de `alunos_turma_a` vira uma instância do módulo, com seus próprios atributos. Isso torna a expansão da turma previsível e fácil de manter.

### 2.4. Saída da camada em `layers/02-alunos/outputs.tf`

A saída principal é o IP de cada container:

```hcl
output "alunos_ip" {
  value       = { for k, v in module.alunos : k => v.ip }
  description = "Lista de IPs mapeados para o inventário do Ansible"
}
```

Essa saída é útil para integrar com automações posteriores, principalmente o Ansible.

---

## 3. Módulo Reutilizável `modules/lxc`

O módulo concentra a criação real do container em um único lugar. Isso é o que permite reaproveitamento em outras camadas ou futuros laboratórios.

### 3.1. Recurso principal em `modules/lxc/main.tf`

```hcl
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.101.0"
    }
  }
}

resource "proxmox_virtual_environment_container" "infra_service" {
  vm_id        = var.vmid
  node_name    = var.target_node
  tags         = sort(var.tags)
  unprivileged = var.unprivileged
  pool_id      = var.pool_id

  cpu {
    cores = var.cores
  }

  memory {
    dedicated = var.memory
    swap      = var.swap
  }

  start_on_boot = true

  dynamic "network_interface" {
    for_each = var.network_interfaces
    content {
      name   = network_interface.value.name
      bridge = network_interface.value.bridge
    }
  }

  initialization {
    hostname = var.hostname

    ip_config {
      ipv4 {
        address = var.ip
        gateway = var.network_config.gateway
      }
    }

    dns {
      domain  = var.dns_domain
      servers = var.dns_servers
    }

    user_account {
      keys     = var.admin_ssh_keys
      password = var.root_password
    }
  }

  operating_system {
    template_file_id = var.template_id
    type             = var.os_type
  }

  disk {
    datastore_id = var.root_disk_storage
    size         = var.root_disk_size
  }

  features {
    nesting = var.nesting
  }

  lifecycle {
    ignore_changes = [
      node_name,
    ]
  }
}
```

Aqui está a principal diferença em relação ao provider antigo. No Telmate, o fluxo era mais próximo de um recurso `proxmox_lxc` com foco em clone e parâmetros de container. No BPG, o recurso `proxmox_virtual_environment_container` organiza melhor a criação do container em blocos semânticos:

1. `cpu` e `memory` descrevem os recursos do container.
2. `initialization` concentra hostname, IP, DNS e credenciais do usuário.
3. `operating_system` aponta diretamente para o template do LXC.
4. `disk` e `features` fecham a definição operacional do container.

O resultado é um código mais legível e mais próximo da estrutura do Proxmox VE.

### 3.2. Variáveis do módulo em `modules/lxc/variables.tf`

O módulo é parametrizado por variáveis específicas para manter o reuso:

```hcl
variable "vmid" { type = number }
variable "hostname" { type = string }
variable "target_node" { type = string }
variable "template_id" { type = string }
variable "cores" { type = number }
variable "memory" { type = number }
variable "swap" { type = number }
variable "ip" { type = string }
variable "tags" { type = list(string) }
variable "unprivileged" { type = bool }
variable "startup_order" { type = string }
variable "root_disk_storage" { type = string }
variable "root_disk_size" { type = number }
variable "admin_ssh_keys" { type = list(string) }
```

As demais variáveis do módulo completam a configuração de rede, DNS, sistema operacional, pool e senha do root. Isso mantém a interface do módulo previsível, mesmo que a implementação evolua.

### 3.3. Saída do módulo em `modules/lxc/outputs.tf`

```hcl
output "ip" {
  value       = var.ip
  description = "IP estático do container"
}
```

Essa saída é repassada pela camada para montar o inventário e facilitar integrações futuras.

---

## 4. O Que Mudou Na Prática

Para fins de documentação histórica, vale registrar a transição entre os providers:

1. `Telmate/proxmox` foi a base inicial de aprendizado e provou que a automatização do LXC era viável.
2. `bpg/proxmox` passou a ser a escolha da versão atual por oferecer um modelo de recurso mais aderente ao Proxmox VE moderno.
3. O desenho atual usa `Vault` para segredos, módulos para reuso e `locals` para declarar a turma de forma legível.

Essa evolução melhora manutenção, clareza e escalabilidade do laboratório.

---

## 5. Resumo Para Replicação

Se alguém quiser reproduzir o projeto a partir desta versão, o fluxo é:

1. Configurar o Vault com os segredos `pm_api_token_secret`, `ssh_public_key` e `lxc_root_password`.
2. Ajustar `layers/02-alunos/provider.tf` com endereço do Vault, token e URL da API do Proxmox.
3. Editar `layers/02-alunos/locals.tf` para refletir a turma, nós, IPs e templates corretos.
4. Executar a camada que chama `modules/lxc/` e validar as saídas de IP.

Com isso, o laboratório fica pronto para escalar sem reescrever o recurso do container a cada nova turma.
