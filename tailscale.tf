data "ns_connection" "tailscale" {
  name     = "tailscale"
  contract = "datastore/gcp/tailscale"
}

locals {
  oauth_client_id   = data.ns_connection.tailscale.outputs.oauth_client_id
  oauth_secret_id   = data.ns_connection.tailscale.outputs.oauth_client_secret_secret_id
  oauth_secret_name = data.ns_connection.tailscale.outputs.oauth_client_secret_secret_name
  tailnet_dns_name  = data.ns_connection.tailscale.outputs.tailnet_dns_name
  default_tag       = data.ns_connection.tailscale.outputs.default_tag

  tags           = [for t in(length(var.tags) > 0 ? var.tags : [local.default_tag]) : "tag:${trimprefix(t, "tag:")}"]
  advertise_tags = join(",", local.tags)
}

// The VM reads the OAuth client secret at boot via the gcp-gce-server secret loader.
resource "google_secret_manager_secret_iam_member" "app_access" {
  secret_id = local.oauth_secret_name
  project   = local.project_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.service_account_email}"
}

// The Tailscale provider needs the OAuth client at plan time to manage the Tailscale Service.
// Only the `services` scope is requested for this token.
data "google_secret_manager_secret_version" "oauth_client_secret" {
  secret = local.oauth_secret_id
}

provider "tailscale" {
  oauth_client_id     = local.oauth_client_id
  oauth_client_secret = data.google_secret_manager_secret_version.oauth_client_secret.secret_data
  scopes              = ["services"]
}
