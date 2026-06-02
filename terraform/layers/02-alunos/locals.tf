# layers/02-alunos/locals.tf

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
      #vmid              = 300
      hostname          = "docker-gerencia.infra.local"
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
    },
    "aluno-02" = {
      #vmid              = 301
      hostname          = "docker-gerencia-02.infra.local"
      target_node       = "testpve02"
      pool_id           = "teste-infra" 
      template_id       = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
      os_type           = "debian"
      cores             = 4  
      memory            = 1024 
      swap              = 512
      ip                = "10.0.40.202/24" 
      tags              = ["IAC", "aluno", "turma-a"]
      unprivileged      = true
      nesting           = true  
      startup_order     = "order=3,up=20"
      root_disk_storage = "local-zfs"
      root_disk_size    = 8
    }
  }
}