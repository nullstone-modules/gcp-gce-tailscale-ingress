// The Tailscale Service users connect to. Its lifecycle follows the app; the VMs advertise it
// via the serve config in serve.tf. Host approval is governed by the tailnet policy
// (autoApprovers.services), which this module does not manage.
resource "tailscale_service" "this" {
  name    = "svc:${local.service_name}"
  comment = "${local.block_name} (${local.env_name}/${local.stack_name}) via gcp-gce-tailscale-ingress"
  ports   = [for l in var.listeners : "tcp:${l.port}"]
  tags    = local.tags

  lifecycle {
    precondition {
      condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", local.service_name))
      error_message = "service_name resolved to \"${local.service_name}\"; it must be a DNS label: lowercase letters, digits, and hyphens, 1-63 characters, not starting or ending with a hyphen."
    }
  }
}
