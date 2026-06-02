# Provisionamento de LXC no Proxmox com Terraform: Guia de Estudo e Replicação

Este documento detalha o código Terraform desenvolvido e a infraestrutura como código (IaC) utilizada no laboratório. Ele serve como **material base para estudo e replicação**, explicando didaticamente as estruturas, módulos e plugins adotados.

A ideia inicial baseou-se no repositório associado ao vídeo do [Mateus Muller](https://www.youtube.com/watch?v=_vit-bn0LyI). Contudo, o código de referência utilizava o provisionamento de **Máquinas Virtuais (VMs)** via *Cloud-Init*.  
Para os nossos propósitos de criar laboratórios rápidos e leves, **o código foi construído do zero**. A abordagem adotada foca em provisionar **Contêineres LXC (Linux Containers)** usando a documentação do [Proxmox Provider (Telmate)](https://registry.terraform.io/providers/Telmate/proxmox/latest/docs/resources/lxc).

---

## 1. O Que é o Proxmox Provider (Telmate)?

O Terraform precisa de "tradutores" para se comunicar com plataformas terceiras, conhecidos como **Providers**. O `Telmate/proxmox` é o provedor não-oficial suportado pela comunidade, sendo o mais utilizado e confiável para integração entre Terraform e Proxmox.

No arquivo `provider.tf`, nós declaramos esse provedor da seguinte maneira:

```hcl
terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc05"
    }
  }
}
```
Isso instrui o Terraform a buscar da sua *Registry* (hub público) a versão específica do plugin capaz de transformar código Terraform em requisições na API do Proxmox.

---

## 2. Entendendo a Base do Nosso Código

O código presente no diretório `terraform-teste/` foi arquitetado para ser modular e seguro. Vamos analisar linha a linha o papel de cada arquivo essencial.

### 2.1. Conexões Seguras com `provider.tf`

No provisionamento corporativo, senhas nunca ficam inseridas no código fonte. Por esta razão, o ambiente conecta-se ao **HashiCorp Vault**.

```hcl
data "vault_kv_secret_v2" "proxmox_secret" {
  mount = "senhas"
  name  = "proxmox"
}

provider "proxmox" {
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = jsondecode(data.vault_kv_secret_v2.proxmox_secret.data_json)["pm_api_token_secret"]
  pm_tls_insecure     = true
}
```
* **`data "vault_kv_secret_v2"`**: O Terraform acessa o Vault na pasta "senhas" e busca o segredo chamado "proxmox".
* **`provider "proxmox"`**: Em seguida, ele estabelece a conexão direta. O `pm_api_token_secret` recebe o seu valor consumindo dinamicamente o dado devolvido do Vault.

### 2.2. A Inteligência de Replicação no `main.tf`

Neste arquivo é onde ocorre a orquestração central. Em vez de escrever 50 blocos de recursos para gerar 50 laboratórios, usamos a construção de **Locals** e **Módulos**:

```hcl
locals {
  alunos_instances = {
    for i in range(var.alunos_count) :
    format("aluno%02d", i + 1) => {
      hostname = format("aluno-%02d", i + 1)
      vmid     = var.alunos_start_vmid + i
      networks = [ { name = "eth0", bridge  = "vmbr1", ip = "dhcp" } ]
    }
  }
}

module "alunos_lxc" {
  source   = "./modules/lxc"
  for_each = local.alunos_instances

  vmid        = each.value.vmid
  hostname    = each.value.hostname
  target_node = var.target_node
  clone_name  = var.lxc_template_name
  # ... repasse das demais variáveis ...
}
```
* **`locals`**: É aqui que acontece o *loop* (`for i in range(...)`). O Terraform monta um inventário de contêineres na variável `alunos_instances`. Automaticamente, cria identificadores, incrementa o nome (`aluno-01`, `aluno-02`) e incrementa o ID interno (`vmid = 300`, `vmid = 301`).
* **`module`**: O laço `for_each = local.alunos_instances` invoca a fábrica ("módulo") quantas vezes existirem alunos configurados e injeta de forma inteligente o mapa de valores por bloco (`each.value.hostname`).

### 2.3. O Módulo Reutilizável (`modules/lxc/main.tf`)

Para organizar nossa infraestrutura como blocos de construção semelhantes (Lego), padronizamos a criação exata do **LXC** em um "módulo":

```hcl
resource "proxmox_lxc" "this" {
  hostname    = var.hostname
  vmid        = var.vmid
  target_node = var.target_node
  clone       = var.clone_name
  full        = true

  password     = var.password
  cores        = var.cores
  memory       = var.memory
  swap         = var.swap
  unprivileged = true

  rootfs {
    storage = var.storage
    size    = var.disk_size
  }

  dynamic "network" {
    for_each = var.networks
    content {
      name   = network.value.name
      bridge = network.value.bridge
      ip     = network.value.ip
    }
  }
}
```
**O que torna esse código base vital para replicação:**
1. **`clone` e `full = true`:** Ao invés de criarmos do zero toda vez, o código determina ao Proxmox para fazer um "Clone Completo" (`full_clone`) de um template padrão já existente (`lxc-base-debian13-v1`). É excepcionalmente rápido.
2. **`unprivileged = true`:** Fator de **segurança**! Configura os contêineres LXC usando a permissão não-privilegiada, impedindo o contêiner de comprometer todo o nó (Node) do hospedeiro, servindo assim um ambiente blindado para os alunos do IFRO.
3. **`rootfs`:** Redimensiona os limites de volume (armazenamento), garantindo o limite base (no nosso projeto de laboratório é de `8G`). 
4. **`dynamic "network"`:** Esta estruturação avançada permite plugar a placa de roteamento base. Como passamos um array de portas de redes, esse bloco as constrói alocando na `vmbr1` (bridge do laboratório) e em `DHCP` (pegará IP localmente).

---

## 3. Parametrização Externa (`terraform.tfvars`)

O último pilar mais importante do modelo IaC proposto é a flexibilidade. Através de variáveis como o arquivo **`terraform.tfvars`**, pessoas e equipes podem reproduzir e reajustar tudo facilmente para as suas realidades físicas sem alterar nenhuma abstração lógica do código `*.tf`.

```hcl
alunos_start_vmid = 300
alunos_count      = 2

default_cores     = 2
default_memory    = 1024
default_disk_size = "8G"
default_storage   = "vms"
```

Se existirem turmas de faculdade com 35 alunos, o simples ajuste na quantidade para `35`, mudará o comportamento de toda a arquitetura de rede, injetará todos os laços de repetição automaticamente e construirá 35 Contêineres isolados no laboratório do Proxmox!
