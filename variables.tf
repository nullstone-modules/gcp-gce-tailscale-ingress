variable "app_metadata" {
  description = <<EOF
Nullstone automatically injects metadata from the app module into this module through this variable.
This variable is a reserved variable for capabilities.
EOF

  type    = map(string)
  default = {}
}

locals {
  data_dir              = var.app_metadata["data_dir"]
  secrets_mount         = var.app_metadata["secrets_mount"]
  service_account_email = var.app_metadata["service_account_email"]
}

variable "service_name" {
  type    = string
  default = ""

  description = <<EOF
Name of the Tailscale Service (without the `svc:` prefix) that fronts this app.
Defaults to `<app>-<env>-<stack>`. The service must exist in the tailnet before hosts can advertise it.
EOF

  validation {
    condition     = var.service_name == "" || can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.service_name))
    error_message = "service_name must be a DNS label: lowercase letters, digits, and hyphens, 1-63 characters, not starting or ending with a hyphen."
  }
}

variable "listeners" {
  type = list(object({
    port     = number
    protocol = optional(string, "https")
    target   = optional(string, "http://127.0.0.1:8080")
  }))
  default = [{ port = 443 }]

  description = <<EOF
Ports the Tailscale Service listens on and where each forwards on the VM.
`protocol` is `https` (TLS terminated with a tailnet certificate), `http`, or `tcp` (raw passthrough).
`target` is a URL for `https`/`http` and a `host:port` for `tcp`.

Example:
```
listeners = [
  { port = 443, target = "http://127.0.0.1:8080" },
  { port = 2022, protocol = "tcp", target = "127.0.0.1:22" },
]
```
EOF

  validation {
    condition     = length(var.listeners) > 0
    error_message = "listeners must contain at least one entry."
  }

  validation {
    condition     = alltrue([for l in var.listeners : contains(["https", "http", "tcp"], l.protocol)])
    error_message = "listeners[*].protocol must be \"https\", \"http\", or \"tcp\"."
  }

  validation {
    condition     = alltrue([for l in var.listeners : l.port >= 1 && l.port <= 65535])
    error_message = "listeners[*].port must be between 1 and 65535."
  }

  validation {
    condition     = length(var.listeners) == length(toset([for l in var.listeners : l.port]))
    error_message = "listeners[*].port must be unique."
  }
}

variable "tags" {
  type    = list(string)
  default = []

  description = <<EOF
Tags to advertise when registering this node with the tailnet. Do not include the `tag:` prefix.
Defaults to the `default_tag` exported by the connected `gcp-tailscale` datastore (`<stack>-<env>`).
Each tag must be owned by the OAuth client in the tailnet policy.
EOF
}

variable "image" {
  type        = string
  default     = "ghcr.io/tailscale/tailscale:v1.102.3"
  description = "Tailscale container image. Pin a tag; the VM pulls whatever this resolves to at service start."
}

variable "container_name" {
  type        = string
  default     = "tailscale"
  description = "Docker container name, also used as the systemd service name."

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9_.-]*$", var.container_name))
    error_message = "container_name must start with a letter or digit and contain only letters, digits, and the characters _ . -"
  }
}
