# modules/lxc-core-service/main.tf

terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.101.0" # Garante consistência com a camada
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
      keys = var.admin_ssh_keys
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