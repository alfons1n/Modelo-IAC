# ================= VAULT =================

variable "vault_address" {
  description = "Endereço do Vault"
  type        = string
}

variable "vault_token" {
  description = "Token de acesso ao Vault (recomendado via variável de ambiente)"
  type        = string
  sensitive   = true
  default     = ""
}


# ================= PROXMOX =================

variable "pm_api_url" {
  description = "URL da API do Proxmox"
  type        = string
}

variable "pm_api_token_id" {
  description = "Token ID do Proxmox (ex: terraform-prov@pve!token)"
  type        = string
}

# segredo vem do Vault
# pm_api_token_secret -> via data.vault


# ================= TEMPLATE LXC =================

variable "lxc_template_name" {
  description = "Nome do template LXC no Proxmox"
  type        = string
}


variable "target_node" {
  description = "Node padrão do Proxmox"
  type        = string
}


# ================= PADRÕES DE CONTAINER =================

variable "default_cores" {
  type    = number
  default = 1
}

variable "default_memory" {
  type    = number
  default = 1024
}

variable "default_disk_size" {
  type    = string
  default = "8G"
}

variable "default_storage" {
  type    = string
  default = "vms"
}

variable "default_swap" {
  type    = number
  default = 512
}


# ================= ALUNOS (LOOP) =================

variable "alunos_start_vmid" {
  description = "VMID inicial para criação dos LXCs"
  type        = number
  default     = 300
}

variable "alunos_count" {
  description = "Quantidade de LXCs de alunos"
  type        = number
  default     = 2
}


# ================= REDE PADRÃO ALUNOS =================

variable "alunos_networks" {
  description = "Configuração padrão de rede para LXCs de alunos"
  type = list(object({
    name   = string
    bridge = string
    ip     = string
    gw     = optional(string)
    tag    = optional(number)
  }))

  default = [
    {
      name   = "eth0"
      bridge = "vmbr0"
      ip     = "dhcp"
      tag    = 510
    }
  ]
}


# ================= FLAGS =================

variable "start_on_create" {
  description = "Iniciar LXC automaticamente após criação"
  type        = bool
  default     = true
}

variable "onboot" {
  description = "Iniciar LXC automaticamente no boot do Proxmox"
  type        = bool
  default     = true
}
