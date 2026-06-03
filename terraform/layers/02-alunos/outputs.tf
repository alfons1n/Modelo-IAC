output "alunos_ip" {
  value       = { for k, v in module.alunos : k => v.ip }
  description = "Lista de IPs mapeados para o inventário do Ansible"
}