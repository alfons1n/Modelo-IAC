output "alunos_lxc_ids" {
  value = {
    for k, m in module.alunos_lxc :
    k => m.id
  }
}

output "alunos_lxc_vmids" {
  value = {
    for k, m in module.alunos_lxc :
    k => m.vmid
  }
}

output "alunos_lxc_hostnames" {
  value = {
    for k, m in module.alunos_lxc :
    k => m.hostname
  }
}
