data "ns_connection" "tailscale" {
  name     = "tailscale"
  contract = "datastore/gcp/tailscale"
}

locals {
  oauth_secret_name = data.ns_connection.tailscale.outputs.oauth_client_secret_secret_name
  tailnet_dns_name  = data.ns_connection.tailscale.outputs.tailnet_dns_name
  default_tag       = data.ns_connection.tailscale.outputs.default_tag

  tags           = length(var.tags) > 0 ? var.tags : [local.default_tag]
  advertise_tags = join(",", [for t in local.tags : "tag:${trimprefix(t, "tag:")}"])
}

// The VM reads the OAuth client secret at boot via the gcp-gce-server secret loader.
resource "google_secret_manager_secret_iam_member" "app_access" {
  secret_id = local.oauth_secret_name
  project   = local.project_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.service_account_email}"
}
