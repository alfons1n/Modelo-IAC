# layers/03-gerencia/provider.tf

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.101.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "5.4.0"
    }
  }
}

provider "vault" {
  address         = var.vault_address
  token           = var.vault_token
  skip_tls_verify = true
}

# DECLARAÇÃO DO DATA SOURCE DO VAULT
data "vault_kv_secret_v2" "proxmox_secret" {
  mount = "senhas"
  name  = "proxmox"
}

provider "proxmox" {
  endpoint  = var.pm_api_url
  api_token = "${var.pm_api_token_id}=${data.vault_kv_secret_v2.proxmox_secret.data["pm_api_token_secret"]}"
  insecure  = true
}

# --- VARIÁVEIS CORRIGIDAS (SEM PONTO E VÍRGULA) ---

variable "vault_address" {
  type = string
}

variable "vault_token" {
  type      = string
  sensitive = true
}

variable "pm_api_url" {
  type = string
}

variable "pm_api_token_id" {
  type = string
}