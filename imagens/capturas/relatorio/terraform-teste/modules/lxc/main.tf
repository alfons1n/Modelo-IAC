resource "proxmox_lxc" "this" {
  hostname    = var.hostname
  vmid        = var.vmid
  target_node = var.target_node
  clone       = var.clone_name
  full        = true

  password     = var.password
  cores        = var.cores
  memory       = var.memory
  swap         = var.swap
  unprivileged = true

  start  = var.start
  onboot = var.onboot

  rootfs {
    storage = var.storage
    size    = var.disk_size
  }

  dynamic "network" {
    for_each = var.networks
    content {
      name   = network.value.name
      bridge = network.value.bridge
      ip     = network.value.ip
      gw     = lookup(network.value, "gw", null)
      tag    = lookup(network.value, "tag", null)
    }
  }
}
