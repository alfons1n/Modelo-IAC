module "gerencia_infrastructure" {
  source   = "../../modules/lxc-core-service"
  for_each = local.alunos_turma_a

  vmid              = each.value.vmid
  vmid              = 0
  hostname          = each.value.hostname
  target_node       = each.value.target_node
  
  #PASSA O VALOR PARA O MÓDULO
  pool_id           = each.value.pool_id 
  
  template_id       = each.value.template_id
  os_type           = each.value.os_type
  cores             = each.value.cores
  memory            = each.value.memory
  swap              = each.value.swap
  ip                = each.value.ip
  network_interfaces = local.network_management.interfaces
  dns_domain  = local.network_management.dns_domain
  dns_servers = local.network_management.dns_servers
  tags              = each.value.tags
  unprivileged      = each.value.unprivileged
  nesting           = each.value.nesting
  startup_order     = each.value.startup_order
  root_disk_storage = each.value.root_disk_storage
  root_disk_size    = each.value.root_disk_size
  network_config    = local.network_management
  admin_ssh_keys = [data.vault_kv_secret_v2.proxmox_secret.data["ssh_public_key"]]
  root_password  = data.vault_kv_secret_v2.proxmox_secret.data["lxc_root_password"]
}