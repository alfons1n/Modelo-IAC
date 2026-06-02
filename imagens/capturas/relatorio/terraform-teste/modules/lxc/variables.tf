variable "hostname" {
  type = string
}

variable "vmid" {
  type = number
}

# ===== Acesso =====

variable "password" {
  type      = string
  sensitive = true
}


variable "target_node" {
  type = string
}

variable "clone_name" {
  type = string
}


# ===== Recursos =====

variable "cores" {
  type    = number
  default = 2
}

variable "memory" {
  type    = number
  default = 1024
}

variable "swap" {
  type    = number
  default = 512
}


# ===== Storage =====

variable "storage" {
  type    = string
  default = "vms"
}

variable "disk_size" {
  type    = string
  default = "8G"
}


# ===== Boot =====

variable "start" {
  type    = bool
  default = true
}

variable "onboot" {
  type    = bool
  default = true
}


# ===== Rede =====

variable "networks" {
  type = list(object({
    name   = string
    bridge = string
    ip     = string
    gw     = optional(string)
    tag    = optional(number)
  }))
}

