terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc05"
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

data "vault_kv_secret_v2" "proxmox_secret" {
  mount = "senhas"
  name  = "proxmox"
}

data "vault_kv_secret_v2" "lxc_secret" {
  mount = "senhas"
  name  = "lxc"
}

locals {
  lxc_password = data.vault_kv_secret_v2.lxc_secret.data["password"]
}

provider "proxmox" {
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = jsondecode(data.vault_kv_secret_v2.proxmox_secret.data_json)["pm_api_token_secret"]
  pm_tls_insecure     = true
}
