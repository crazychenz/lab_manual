---
sidebar_position: 5
title: Passwords
---

:::danger Incomplete

This document is not yet written.

:::

<!-- ```sh
sudo su -c "mkdir -p /opt/initial/words && chown user /opt/initial/words"
mkdir -p /opt/initial/words/state/data
```

```yaml
version: '3'

services:
  vaultwarden_svc:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    restart: unless-stopped
    environment:
      DOMAIN: "https://words.lab"
    ports: [127.0.0.1:1080:80, 127.0.0.1:3012:3012]
    volumes:
      - ./state/data:/data
``` -->

- `docker compose up -d vaultwarden_svc`

Optionally access from a dev machine by modifying the /etc/hosts file. c/windows/system32/drivers/etc/hosts (reset chrome or browser to reload)

Open https://words.lab in browser and "Create Account"

After you've filled in the email (user@lab), name (user), and password (gofishpassword), create account then login with new account.

You can now store all of your sensitive credentials in this password manager. Vaultwarden also supports secure note storage and attachments. This can be useful for private keys or other tokens that aren't strictly a password (e.g. Storage Bucket credentials).

