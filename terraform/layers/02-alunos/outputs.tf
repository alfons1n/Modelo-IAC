output "docker_host_ips" {
  value       = { for k, v in module.gerencia_infrastructure : k => v.ip }
  description = "Lista de IPs mapeados para o inventário do Ansible"
}