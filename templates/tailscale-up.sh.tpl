#!/usr/bin/env bash
# Managed by gcp-gce-tailscale-ingress. Starts the Tailscale node that advertises this app's Tailscale Service.
set -euo pipefail

# Secrets live on tmpfs and clear on reboot; re-run the server loader on every start.
/etc/nullstone/load-app-secrets.sh
key_file="${secrets_mount}/${authkey_file}"
test -s "$${key_file}" || { echo "$${key_file} missing (server secret loader did not run); refusing to start"; exit 1; }

# Container env is assembled on the same tmpfs so the auth key never touches disk.
# The OAuth client secret is used directly as an auth key; ephemeral nodes are removed when offline,
# preauthorized skips device approval.
env_file="${secrets_mount}/${container_name}.env"
umask 077
printf 'TS_AUTHKEY=%s?ephemeral=true&preauthorized=true\n' "$(cat "$${key_file}")" > "$${env_file}"
umask 022

mkdir -p "${state_dir}"

# Each VM is its own tailnet node. Name it after the GCE instance so node names are unique per VM,
# match the GCE console, and never collide with the Tailscale Service name users connect to.
instance_name="$(curl -sf -H 'Metadata-Flavor: Google' http://metadata.google.internal/computeMetadata/v1/instance/name || true)"
node_hostname="$${instance_name:-${fallback_hostname}}"

docker rm -f ${container_name} 2>/dev/null || true
docker run -d --name ${container_name} --restart unless-stopped \
  --network host \
  --env-file "$${env_file}" \
  -e TS_USERSPACE=true \
  -e TS_HOSTNAME="$${node_hostname}" \
  -e TS_STATE_DIR=/var/lib/tailscale \
  -e TS_AUTH_ONCE=true \
  -e TS_ACCEPT_DNS=false \
  -e TS_EXTRA_ARGS=--advertise-tags=${advertise_tags} \
  -e TS_SERVE_CONFIG=/config/serve.json \
  -v "${state_dir}:/var/lib/tailscale" \
  -v "${serve_config_path}:/config/serve.json:ro" \
  ${image}
