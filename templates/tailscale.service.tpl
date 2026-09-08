[Unit]
Description=${container_name} (Tailscale Service ingress via gcp-gce-tailscale-ingress)
After=network-online.target docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=${up_sh_path}
ExecStop=/usr/bin/docker rm -f ${container_name}

[Install]
WantedBy=multi-user.target
