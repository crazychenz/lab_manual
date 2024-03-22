---
sidebar_position: 4
title: HTTP & CA
draft: true
---

:::danger Incomplete

This document is not yet written.

:::

## Caddy

Caddy is a modern web server written in Golang. In addition to the golang static binary, it also benefits from a built-in and managed certificate authority. Essentially, caddy provides HTTPS by default and out of the box. At the time of this writing there is definately room for improvement in the security posture of the product. That said, its modular design, simple configuration, and security biased principles vastly outweight its lackings.

## The Procedure

- Prepare the system
- Install and configure caddy with docker compose
- Install caddy root certificate into host system


## Preparing The System

```sh
sudo su -c "mkdir -p /opt/initial/caddy && chown user /opt/initial/caddy"
mkdir -p /opt/initial/caddy/state/{data,config}
touch /opt/initial/caddy/state/Caddyfile
```

## Configure Caddy

For the caddy configuration, we're going to add a few host routed endpoints. Each endpoint is going to be a localhost accessible service. The following sets up 4 different services that we'll setup later. 

`/opt/initial/caddy/state/Caddyfile`:

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

Note: You can add as many services as you'd like at this point. As long as the syntax is correct, caddy should be ok with it, even if it isn't setup yet. If you attempt to visit these sites before they are setup, caddy will return a 500 error code indicating that itself can not serve you as a reverse proxy.

## Install Caddy via Docker Compose

Mostly from: https://caddyserver.com/docs/running#docker-compose

Below, we run caddy during our container image build to generate certificate and host certificate from a standard static web server folder. All subsequent container builds may then use curl/wget to fetch the root certificate from this caddy image/container.

```


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
      - /opt/state/caddy_svc/data:/data
      - /opt/state/caddy_svc/config:/config
```

With the `docker-compose.yml` done, run the following:

- `docker compose build && docker compose up -d`

## Install Caddy Root Certificate

- Copy certificate out of docker-compose service and install in Linux host.

    ```sh
    docker compose cp \
        caddy_svc:/data/caddy/pki/authorities/local/root.crt \
        /usr/local/share/ca-certificates/root.crt \
      && sudo update-ca-certificates
    ```

- Copy certificate out of docker-compose service and install in Windows host.

    ```sh
    docker compose cp \
      caddy_svc:/data/caddy/pki/authorities/local/root.crt \
      %TEMP%/root.crt \
    && certutil -addstore -f "ROOT" %TEMP%/root.crt
    ```

- Copy certificate from running caddy service and install in a host.

    ```sh
    sudo curl -k https://tls.lab/certs/root.crt -o /usr/local/share/ca-certificates/lab-root.crt
    sudo ln -s /usr/local/share/ca-certificates/lab-root.crt /etc/ssl/certs/lab-root.crt
    sudo update-ca-certificates
    ```

    - Restart docker for the update to take effect:
    
        ```sh
        sudo systemctl restart docker
        docker login -u gitea_user git.lab
        ```




