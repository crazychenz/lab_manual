---
sidebar_position: 4
title: HTTP & CA
---

:::danger Incomplete

This document is not yet written.

:::

## Contents

- Prepare the system
- Install and configure caddy with docker compose
- Install caddy root certificate into host system
  - `sudo curl -k https://tls.lab/certs/root.crt -o /usr/local/share/ca-certificates/lab-root.crt`
  - `sudo ln -s /usr/local/share/ca-certificates/lab-root.crt /etc/ssl/certs/lab-root.crt`
  - `sudo update-ca-certificates`
  - Restart docker for the update to take effect: `sudo systemctl restart docker`
  - `docker login -u gitea_user git.lab`


Mostly from: https://caddyserver.com/docs/running#docker-compose

```sh
sudo su -c "mkdir -p /opt/initial/caddy && chown user /opt/initial/caddy"
mkdir -p /opt/initial/caddy/state/{data,config}
touch /opt/initial/caddy/state/Caddyfile
```

**TODO**: Need to run caddy during build to generate certificate and host certificate from a standard static web server folder. All subsequent container builds would then use curl/wget to fetch the root certificate from this caddy image/container.



```yaml
services:
  caddy_svc:
    image: git.lab/lab/caddy:initial
    build:
      context: .
      dockerfile_inline: |
        FROM caddy:alpine
        
        # Execute Caddy's PKI application to create certificates.
        COPY <<EOF /tmp/init-pki.sh
        # Start the server
        caddy run &
        TMP_CADDY_PID=\$!
        # Wait for server to start
        sleep 1
        # Tell caddy to gen certs (and install them).
        caddy trust
        # Wait for server to create certificates
        sleep 1
        # Kill server
        kill \$\{TMP_CADDY_PID\}
        # Copy public certs to hosted folder 
        mkdir -p /public/certs
        cp /data/caddy/pki/authorities/local/*.crt /public/certs/
        EOF
        # Set execute perm, execute, and remove the initialize PKI script.
        RUN chmod +x /tmp/init-pki.sh && /tmp/init-pki.sh && rm /tmp/init-pki.sh
        
        # Build the container entrypoint
        COPY <<EOF /start-caddy.sh
        #!/bin/sh
        caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
        EOF
        RUN chmod +x /start-caddy.sh
        CMD ["/start-caddy.sh"]

    container_name: caddy_svc
    restart: unless-stopped
    network_mode: host

    volumes:
      - ./state/Caddyfile:/etc/caddy/Caddyfile
      - ./state/data:/data
      - ./state/config:/config
```

```
docker compose cp \
    caddy_svc:/data/caddy/pki/authorities/local/root.crt \
    %TEMP%/root.crt \
  && certutil -addstore -f "ROOT" %TEMP%/root.crt
```

```
docker compose cp \
    caddy_svc:/data/caddy/pki/authorities/local/root.crt \
    /usr/local/share/ca-certificates/root.crt \
  && sudo update-ca-certificates
```

```
https://words.lab {
  tls internal
  
  reverse_proxy http://127.0.0.1:1080 {
    header_up Host {host}
    header_up X-Real-IP {remote}
  }
}

https://git.lab {
  tls internal
  
  reverse_proxy http://127.0.0.1:1180 {
    header_up Host {host}
    header_up X-Real-IP {remote}
  }
}

https://www.lab {
  tls internal
  
  reverse_proxy http://127.0.0.1:1280 {
    header_up Host {host}
    header_up X-Real-IP {remote}
  }
}
```

