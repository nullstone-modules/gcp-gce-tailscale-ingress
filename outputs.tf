# Consumed by gcp-gce-server as local.capabilities.secret_files.
# The OAuth client secret is materialized at boot under SECRETS_MOUNT_DIR as <name>.
output "secret_files" {
  value = [
    {
      name      = local.authkey_file
      secret_id = local.oauth_secret_name
    }
  ]
}

output "cloud_init_stanzas" {
  description = "Cloud-init write_files and runcmd contributed to the parent gcp-gce-server module."
  value = [
    {
      write_files = local.cloud_init_write_files
      runcmd      = local.cloud_init_runcmd
    }
  ]
}

output "private_urls" {
  value = [for url in local.listener_urls : { url = url }]
}
