// Resolves var.service_name, interpolating {{ NULLSTONE_* }} identifiers.
// Default naming matches gcp-gke-tailscale-ingress: <app>-<env>-<stack>.
locals {
  service_name_input = coalesce(var.service_name, "{{ NULLSTONE_APP }}-{{ NULLSTONE_ENV }}-{{ NULLSTONE_STACK }}")
}

data "ns_env_variables" "service_name" {
  input_env_variables = {
    NULLSTONE_STACK = local.stack_name
    NULLSTONE_APP   = local.block_name
    NULLSTONE_BLOCK = local.block_name
    NULLSTONE_ENV   = local.env_name
    SERVICE_NAME    = local.service_name_input
  }
  input_secrets = {}
}

locals {
  service_name = data.ns_env_variables.service_name.env_variables["SERVICE_NAME"]
}
