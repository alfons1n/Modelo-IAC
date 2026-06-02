locals {
  alunos_instances = {
    for i in range(var.alunos_count) :
    format("aluno%02d", i + 1) => {
      hostname = format("aluno-%02d", i + 1)
      vmid     = var.alunos_start_vmid + i
      networks = [
        {
          name   = "eth0"
          bridge = "vmbr1"
          ip     = "dhcp"
        }
      ]
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
  password    = local.lxc_password
  cores     = var.default_cores
  memory    = var.default_memory
  disk_size = var.default_disk_size
  storage   = var.default_storage

  networks = each.value.networks
  start  = var.start_on_create
}
