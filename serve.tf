// The app is reached through a Tailscale Service (svc:<name>) rather than a node name.
// Every VM in the MIG advertises the same service, so the URL is stable across rollouts:
// clients stick to one healthy host and fail over when it goes away.
locals {
  // Same naming as gcp-gke-tailscale-ingress: <app>-<env>-<stack>.
  service_name = "${local.block_name}-${local.env_name}-${local.stack_name}"
  service_fqdn = "${local.service_name}.${local.tailnet_dns_name}"

  // ipn.ServeConfig shape. Built per protocol and merged because conditional branches must share a type.
  serve_tcp = merge(
    { for l in var.listeners : tostring(l.port) => { HTTPS = true } if l.protocol == "https" },
    { for l in var.listeners : tostring(l.port) => { HTTP = true } if l.protocol == "http" },
    { for l in var.listeners : tostring(l.port) => { TCPForward = l.target } if l.protocol == "tcp" },
  )
  serve_web = {
    for l in var.listeners : "${local.service_fqdn}:${l.port}" => {
      Handlers = { "/" = { Proxy = l.target } }
    } if l.protocol != "tcp"
  }

  serve_config = jsonencode({
    Services = {
      "svc:${local.service_name}" = merge(
        { TCP = local.serve_tcp },
        length(local.serve_web) > 0 ? { Web = local.serve_web } : {},
      )
    }
  })

  listener_urls = [
    for l in var.listeners :
    l.protocol == "tcp" ? "tcp://${local.service_fqdn}:${l.port}" :
    format("%s://%s%s", l.protocol, local.service_fqdn,
      (l.protocol == "https" && l.port == 443) || (l.protocol == "http" && l.port == 80) ? "" : ":${l.port}"
    )
  ]
}
