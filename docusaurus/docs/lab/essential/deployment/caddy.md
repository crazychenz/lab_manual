---
sidebar_position: 4
title: HTTP & CA
---

:::danger Incomplete

All of the documents in GODS documentation are currently being rewritten.

:::

## Overview

Caddy is a modern web server written in Golang. In addition to the golang static binary, it also benefits from a built-in and managed certificate authority. Essentially, caddy provides HTTPS out of the box by default. At the time of this writing there is definitely room for improvement in the security posture of the product, but its modular design, simple configuration, and security biased principles vastly outweigh its lackings.

When we setup our primary HTTP/HTTPS router (i.e. caddy), we'll be first running an initialization container to ensure certificates are generated before running the caddy service. Caddy does do this on its own, but we have a couple of things happening:

- The certificates generated from Caddy should remain somewhat stable, regardless of configuration updates or container image updates.

- Private certificate keys, while available to Caddy, should be kept separate in revision control for security purposes.

- The (public) certificates generated from Caddy should be easily accessible to other nodes on our network so that we can install relevant certificates with a quick remote shell command.

## The Initializer

The following docker compose yaml is the descriptor for the caddy certificate initialization (`/opt/services/lab_services/services/caddy_certs_init.yml`):

```
services:
  caddy_certs_init:
    image: git.lab/lab/caddy:certs_init
    container_name: caddy_certs_init
    build: 
      #context: 
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
```

Since docker doesn't permit volume mounting during builds, we setup the initialization container so that it's default command is a script for telling caddy to setup a PKI. Once this is complete, we copy the certificate and private signing keys to a mounted volume for the real caddy service to use.

If the script detects that the certificate and key files already exist, it reports this to the console and exits to preserve the certificates that we might have already installing a a bazillion other nodes on the network.

You should build and run the `caddy_certs_init` service before `caddy_svc` to ensure everything has been configured correctly. Once you know its working as expected, it's recommended to let `caddy_svc` run the service itself:

```sh
cd /opt/services/lab_services/services/
docker compose -f caddy_certs_init.yml build
docker compose -f caddy_certs_init up
```

## The Caddy Service

The following docker compose yaml is the descriptor for the caddy (HTTPS) services (`/opt/services/lab_services/services/caddy_svc.yml`):

```
services:
  caddy_svc:
    image: git.lab/lab/caddy:initial
    depends_on:
      caddy_certs_init: { condition: service_completed_successfully }
      dnsmasq_svc: { condition: service_started }
    container_name: caddy_svc
    build: 
      context: ../contexts/caddy_svc
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
```

This caddy service container has it's configuration file (`Caddyfile`) embedded into the container image. When the container starts, it always copies the public certificates to a `/public/certs` folder so that clients can easily access certificates via `https://tls.lab/certs/`. The certificates are made available to the container via the `/opt/state/caddy_certs_init` volume mount.

<!-- TODO: Come up with a better file index and 302 a host for certs to it. -->

One of the key things for this container are its dependencies. This container requires that `caddy_certs_init` have run, but it must no longer be running. This provides a reasonable guarantee that the certificate files will be available when the service starts and prevents caddy from regenerating new certificates. There is also a requirement for `dnsmasq_svc` to be running, even though that isn't strictly required for the initial `Caddyfile` that we've embedded.

To build and run the `caddy_svc` service:

```sh
cd /opt/services/lab_services/services/
docker compose -f caddy_svc.yml build
docker compose -f caddy_svc.yml up -d
```

## Configure Caddy

For the caddy configuration, we've added a few host routed endpoints. Each endpoint is going to be a localhost accessible service. (The `Caddyfile` will eventually remain revision controlled and therefore can be embedded into the docker image.)

`/opt/services/lab_services/contexts/caddy_svc/Caddyfile`:

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

## Install Caddy Root Certificate

- Copy certificate out of docker-compose service and install in Linux host.

    ```sh
    docker compose cp \
        caddy_svc:/data/caddy/pki/authorities/local/root.crt \
        /usr/local/share/ca-certificates/lab-root.crt \
      && sudo update-ca-certificates
    ```

- Copy certificate out of docker-compose service and install in Windows host.

    ```sh
    docker compose cp \
      caddy_svc:/data/caddy/pki/authorities/local/root.crt \
      %TEMP%/lab-root.crt \
    && certutil -addstore -f "ROOT" %TEMP%/root.crt
    ```

- Copy certificate from running caddy service and install in a Linux host.

    ```sh
    sudo curl -k https://tls.lab/certs/root.crt \
      -o /usr/local/share/ca-certificates/lab-root.crt
    sudo update-ca-certificates
    ```

- Copy certificate from running caddy service and install in Linux without `update-ca-certificates`:

    ```sh
    sudo wget --no-check-certificate https://tls.lab/certs/root.crt \
      -O /usr/local/share/ca-certificates/lab-root.crt \
      && cat /usr/local/share/ca-certificates/lab-root.crt \
        | sudo tee -a /etc/ssl/certs/ca-certificates.crt
    ```

- **!!** Restart docker for the update to take effect: **!!**
    
    ```sh
    sudo systemctl restart docker
    docker login -u gitea_user git.lab
    ```
