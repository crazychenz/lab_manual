---
sidebar_position: 5
title: Passwords
---

## Overview

## The Steps

Notice the vaultwarden related snippet of yaml from our initial services `docker-compose.yml` file:

```
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
```

Vaultwarden is the first of our services that will require caddy for access. It is also  the first of our services that are not running in `network_mode: host` (i.e. it has its own network namespace). Even so, we explicitly map the vaultwarden container listeners to localhost and use `caddy_svc` as its TLS terminator and reverse proxy. In our `docker-compose.yml` snippet above, we define the host name that we want vaultwarden to identify as and the ports that we want to expose.

## Initial Account

Note: If you are accessing the host via SSH on a LAN, you can access your vaultwarden service from an end-user OS like Linux Desktop or Mac OS by modifying the `/etc/hosts` file. For windows, the `/etc/hosts` file is at `C:\\windows\\system32\\drivers\\etc\\hosts`. You need to run your text editor as Administrator to update and you'll have to reset Chrome and other browsers for the changes to take effect.

Open [https://words.lab](https://words.lab) in browser and "Create Account"

After you've filled in the email (`user@lab`), name (`user`), and password (`gofishpassword`), create account then login with new account.

You can now store all of your sensitive credentials in this password manager. Vaultwarden also supports secure note storage and attachments. This can be useful for private keys or other tokens that aren't strictly a password (e.g. Storage Bucket credentials).

## Backup

:::danger Incomplete

To be written.

:::
