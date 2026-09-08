# gcp-gce-tailscale-ingress

Nullstone capability that exposes a port on a `gcp-gce-server` VM to a tailnet as a
[Tailscale Service](https://tailscale.com/docs/features/tailscale-services) named
`<app>-<env>-<stack>` (same naming as `gcp-gke-tailscale-ingress`).

Reaches ports bound to `127.0.0.1` on the VM, so an admin port published with
`host_ip: "127.0.0.1"` by `gcp-gce-docker-app` stays private to the VM and the tailnet.

## How it works

1. Connects to a `gcp-tailscale` datastore for the OAuth client secret and tailnet DNS name, and
   grants the VM service account read access to that secret.
2. Contributes cloud-init that runs the `tailscale/tailscale` image as `<container_name>.service`
   with host networking and userspace networking (no tun device, no `NET_ADMIN`). Inbound tailnet
   traffic only reaches what `serve` publishes.
3. Renders a declarative serve config advertising `svc:<app>-<env>-<stack>` with one listener per
   entry in `listeners`.

Every VM in the managed instance group advertises the same service. Clients stick to one healthy
host and fail over when it goes away, so the URL does not change during a rollout. Nodes register
as ephemeral and are removed from the tailnet once offline.

## Tailnet prerequisites

In the Tailscale admin console:

- MagicDNS and HTTPS certificates enabled (DNS tab) for `https` listeners.
- The tag in `tags` (default `<stack>-<env>`) declared in `tagOwners` and owned by the OAuth client.
- Service hosts auto-approved, or approve each VM by hand after every rollout:
  ```json
  "autoApprovers": { "services": { "svc:<app>-<env>-<stack>": ["tag:<stack>-<env>"] } }
  ```
- A grant from users to the service, e.g. `"dst": ["svc:<app>-<env>-<stack>"]`.

Egress needs nothing beyond the server's Cloud NAT.

## Inputs

| Name             | Default                                     | Description |
|------------------|---------------------------------------------|-------------|
| `listeners`      | `[{ port = 443 }]`                          | Service ports. `protocol` is `https`, `http`, or `tcp`; `target` defaults to `http://127.0.0.1:8080` (use `host:port` for `tcp`). |
| `tags`           | `[]` (datastore `default_tag`)              | Tags to advertise, without `tag:`. |
| `image`          | `ghcr.io/tailscale/tailscale:v1.102.3`      | Tailscale image. |
| `container_name` | `tailscale`                                 | Docker container and systemd unit name. |

`app_metadata` is injected by Nullstone; `data_dir`, `secrets_mount`, and `service_account_email`
are read from it.

## Outputs

| Output               | Purpose |
|----------------------|---------|
| `secret_files`       | Materializes the OAuth client secret on the server secrets mount (tmpfs). |
| `cloud_init_stanzas` | `write_files` and `runcmd` consumed by `gcp-gce-server`. |
| `private_urls`       | One URL per listener, e.g. `https://<app>-<env>-<stack>.<tailnet>.ts.net`. |

## Example

```yaml
capabilities:
  tailscale:
    module: nullstone/gcp-gce-tailscale-ingress
    connections:
      tailscale: tailscale
    vars:
      listeners:
      - port: 443
        target: "http://127.0.0.1:8080"
```

## Operations

```bash
systemctl status tailscale
docker logs tailscale
docker exec tailscale tailscale status
```

State lives at `<data_dir>/tailscale`. Deleting it forces a fresh node registration on next start.
