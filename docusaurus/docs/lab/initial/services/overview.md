---
sidebar_position: 1
title: Services Synopsis
---

## Synopsis

Below are the descriptions and configurations that will go into the following explanations. If you already know what you're doing, I've dropped the bottom line up front for you to grab or reference what you need without having to weed through any/all of the explanation in the following pages.

For more information, please see the relevant explanation page:

- DNS (_Coming Soon_)
- Caddy (_Coming Soon_)
- Vaultwarden (_Coming Soon_)
- Gitea (_Coming Soon_)

## `Caddyfile`

The `./context/Caddyfile` configuration used in the creation of `caddy_svc`:

```Caddyfile
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

https://tls.lab {
  tls internal
  
  root * /public
  file_server browse
}
```

## `docker-compose.yml`

```yaml
# Compose v2

## Quick port mapping reference.
# dnsmasq_svc - host networking on port 0.0.0.0:53
# caddy_svc - host networking on ports 0.0.0.0:80, 0.0.0.0:443, 127.0.0.1:2019
# vaultwarden_svc - 127.0.0.1:1080:80, 127.0.0.1:3012:3012
# gitea_svc - 127.0.0.1:1180:3000, 22:22

services:
  dnsmasq_svc:
    image: git.lab/lab/dnsmasq:initial
    depends_on: []
    container_name: dnsmasq_svc
    build:
      context: context
      dockerfile_inline: |
        FROM alpine:3.19
        RUN apk add -U dnsmasq
    restart: unless-stopped
    network_mode: host
    dns:
    - 9.9.9.9
    - 1.1.1.1
    dns_search: lab
    extra_hosts:
    - dockerhost:host-gateway
    - git.lab:192.168.1.213
    - words.lab:192.168.1.213
    - dns.lab:192.168.1.213
    - www.lab:192.168.1.213
    - tls.lab:192.168.1.213
    entrypoint: ["/usr/sbin/dnsmasq", "--no-daemon"]


  caddy_certs_init:
    image: git.lab/lab/caddy:certs_init
    container_name: caddy_certs_init
    build: 
      context: context
      dockerfile_inline: |
        FROM caddy:alpine
        
        # Execute Caddy's PKI application to create certificates.
        COPY <<EOF /init-pki.sh
        #!/bin/sh

        # If certificates are valid, return success.
        if [ -e /certs/root.key -a -e /certs/root.crt ]; then
          echo "Found certificates."
          exit 0
        fi

        echo "No certificates found, created them now."
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
        mkdir -p /certs
        cp /data/caddy/pki/authorities/local/* /certs/
        # Return success
        exit 0
        EOF
        # Set execute perm, execute, and remove the initialize PKI script.
        RUN chmod +x /init-pki.sh

        CMD ["/init-pki.sh"]
    network_mode: host
    volumes:
      - /opt/state/caddy_certs_init/:/certs


  caddy_svc:
    image: git.lab/lab/caddy:initial
    depends_on:
      caddy_certs_init: { condition: service_completed_successfully }
      dnsmasq_svc: { condition: service_started }
    container_name: caddy_svc
    build: 
      context: context
      dockerfile_inline: |
        FROM caddy:alpine
        
        COPY Caddyfile /etc/caddy/Caddyfile
        
        # Build the container entrypoint
        COPY <<EOF /start-caddy.sh
        #!/bin/sh
        mkdir -p /public/certs
        cp /data/caddy/pki/authorities/local/*.crt /public/certs
        caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
        EOF
        RUN chmod +x /start-caddy.sh
        CMD ["/start-caddy.sh"]

    restart: unless-stopped
    network_mode: host
    volumes:
      - /opt/state/caddy_svc/config:/config
      - /opt/state/caddy_certs_init:/data/caddy/pki/authorities/local


  vaultwarden_svc:
    image: vaultwarden/server:latest
    depends_on: [dnsmasq_svc, caddy_svc]
    container_name: vaultwarden_svc
    restart: unless-stopped
    environment:
      DOMAIN: "https://words.lab"
    ports: [127.0.0.1:1080:80, 127.0.0.1:3012:3012]
    volumes:
      - /opt/state/vaultwarden_svc/data:/data


  gitea_svc:
    image: gitea/gitea:1.21.4
    depends_on: [dnsmasq_svc, caddy_svc]
    container_name: gitea_svc
    environment:
      - USER_UID=1000
      - USER_GID=1000
    restart: unless-stopped
    volumes:
      - /opt/state/gitea_svc/data:/data
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    ports: [ 127.0.0.1:1180:3000, "22:22" ]


  gitea_sys_runner:
    image: git.lab/lab/act_runner:latest
    depends_on: [dnsmasq_svc, caddy_svc, gitea_svc]
    build:
      context: context
      dockerfile_inline: |
        FROM gitea/act_runner:latest-dind-rootless
        USER root
        RUN wget --no-check-certificate https://tls.lab/certs/root.crt \
          -O /etc/ssl/certs/lab-root.crt \
          && wget --no-check-certificate https://tls.lab/certs/intermediate.crt \
          -O /etc/ssl/certs/lab-intermediate.crt \
          && cat /etc/ssl/certs/lab-root.crt /etc/ssl/certs/ca-certificates.crt \
          && cat /etc/ssl/certs/lab-intermediate.crt >> /etc/ssl/certs/ca-certificates.crt
        USER rootless
    container_name: gitea_sys_runner
    # Required for docker in docker control.
    privileged: true
    environment:
      - CONFIG_FILE=/data/config.yaml
      - DOCKER_HOST=unix:///var/run/user/1000/docker.sock
    volumes:
      - /opt/state/gitea_sys_runner/data:/data
    restart: unless-stopped

```

To run this docker file, you must first initialize the environment:

```
# Change your host SSH port to something other than port 22
# Ensure /etc/resolv.conf is pointing at a working DNS (e.g. 9.9.9.9)
docker compose build dnsmasq_svc
docker compose build caddy_certs_init
docker compose build caddy_svc
docker compose up -d caddy_svc
# Ensure /etc/resolv.conf is pointing at ourself (i.e. dnsmasq_svc)
docker compose build vaultwarden_svc
docker compose build gitea_svc
docker compose build gitea_sys_runner
```

After that, you can then run the standard stop and start commands:

```
docker compose down
docker compose up -d
```

