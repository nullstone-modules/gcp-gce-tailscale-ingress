locals {
  // /etc/nullstone is the server-owned, COS-writable scaffold dir (see gcp-gce-server README).
  ts_dir            = "/etc/nullstone/tailscale"
  serve_config_path = "${local.ts_dir}/serve.json"
  up_sh_path        = "${local.ts_dir}/tailscale-up.sh"
  // Node state on the boot disk: survives reboots and container restarts, not MIG replacement.
  // Nodes are ephemeral, so a replaced VM is a new node and the old one is removed once offline.
  state_dir = "${local.data_dir}/tailscale"
  // Name of the secret file gcp-gce-server materializes under secrets_mount (see output.secret_files).
  authkey_file = "tailscale-oauth-secret"
  service_unit = "${var.container_name}.service"

  tailscale_up_sh = templatefile("${path.module}/templates/tailscale-up.sh.tpl", {
    container_name = var.container_name
    image          = var.image
    // Node hostname is the GCE instance name (read from metadata at boot); this is only the fallback.
    fallback_hostname = "${local.service_name}-node"
    advertise_tags    = local.advertise_tags
    secrets_mount     = local.secrets_mount
    authkey_file      = local.authkey_file
    state_dir         = local.state_dir
    serve_config_path = local.serve_config_path
  })

  tailscale_service = templatefile("${path.module}/templates/tailscale.service.tpl", {
    container_name = var.container_name
    up_sh_path     = local.up_sh_path
  })

  cloud_init_write_files = [
    {
      path        = local.serve_config_path
      permissions = "0644"
      owner       = "root:root"
      content     = local.serve_config
    },
    {
      path        = local.up_sh_path
      permissions = "0755"
      owner       = "root:root"
      content     = local.tailscale_up_sh
    },
    {
      path        = "/etc/systemd/system/${local.service_unit}"
      permissions = "0644"
      owner       = "root:root"
      content     = local.tailscale_service
    },
  ]
  cloud_init_runcmd = [
    "systemctl daemon-reload",
    "systemctl enable --now ${local.service_unit}",
  ]
}
