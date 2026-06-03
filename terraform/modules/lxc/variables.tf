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

variable "network_config" {
  type = object({
    bridge  = string
    gateway = string
  })
}

variable "pool_id" {
  type        = string
  default     = null # Opcional: permite criar o LXC sem pool se não for especificado
  description = "O ID do Resource Pool pré-criado no Proxmox"
}

variable "nesting" {
  type        = bool
  default     = false
  description = "Permite rodar Docker/Containers dentro do LXC"
}

variable "os_type" {
  type        = string
  description = "O tipo de sistema operacional (ex: debian, ubuntu, alpine)"
}
variable "dns_domain" {
  type        = string
  default     = null # Se não for passado, o Proxmox usa o padrão do host
  description = "Domínio de busca DNS para o container"
}

variable "dns_servers" {
  type        = list(string)
  default     = [] # Se vazio, usa os servidores DNS do host
  description = "Lista de IPs de servidores DNS"
}
# modules/lxc-core-service/variables.tf

variable "root_password" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Senha do usuário root para acesso via console web"
}

variable "network_interfaces" {
  type = list(object({
    name   = string
    bridge = string
  }))
  description = "Lista de objetos contendo as interfaces de rede e suas respectivas bridges"
}