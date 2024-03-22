---
sidebar_position: 6
title: Gitea
---

## Overview

Git is a popular revision control system written and maintained for Linux kernel maintenance. Since it was originally released, its somehow grown into its own thing that is world know. Centralized services like GitHub, GitLab, and BitBucket have popped up with critical software development features like issue tracking, DevOps workflows, wiki documentation, online editing, binary artifact hosting, and a long list of other features. Many of the core features exist in a relatively small and self-contained golang implementation called Gitea.

In the GitOps Driven Stack, we'll use Gitea as our authoritative upstream repository, the thing that triggers various critical runners, and a local/private docker registry for containers that are built when updates are pushed upstream.

## The Steps

Before we create our gitea service container, it is recommended that you change the host SSH port to something other than 22. This is because we're going to permit gitea to control port 22 for git related operations. I personally prefer port `2222`.

- Reconfigure SSHd to use a different port (e.g. 2222) in `/etc/ssh/sshd_config`.

- Reset the ssh service. (`sudo systemctl restart sshd`)

Notice the gitea related snippet of yaml from our initial services `docker-compose.yml` file:

```
services:
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
```

In this service, we explicitly map gitea's website and other web services hosted on port `3000` to our host's `localhost:1180` to enforce `caddy_svc` as the TLS terminator and reverse proxy. The host ssh port `22` is also mapped so that there is no weird funnyness with git over ssh commands. Without permitting this, git commands and environment variable definitions get really dirty and hard to maintain over any number of nodes and platforms.

<!-- - Create initial gitea folder.

  - `sudo su -c "mkdir -p /opt/initial/gitea && chown -R $(id -u) /opt/initial"` -->

<!-- - **TODO:** Create a custom act_runner with caddy root certificate. This is accomplished, in Alpine, by appending the root certificate to `/etc/ssl/certs/ca-certificates.crt`. Copy cert to `/usr/local/share/ca-certificates` when using `update-ca-certificates` command. -->


<!-- - Modify the USER_UID/USER_GID to match the gitea user values. -->

- `docker compose up -d gitea_svc`

## Initial Service Setup

- Open Gitea via its hostname ([https://git.lab/](https://git.lab/)) from `dnsmasq_svc` in a browser on the same network. 

- Leave the defaults and click "Install Gitea" button- toward the bottom of the page.

- On the next screen (i.e. the login screen), click "Need an account? Register Now."

  - Select a username (e.g. `gitea_user`) and a password > 8 characters (e.g. `password`), then click "Register Account".

  - Note: If you forget the password, you can reset it with:

    ```sh
    docker exec -it <container-id> su git bash -c "gitea admin user change-password -u <user> -p <pw>"
    ```

- We now have an operating git revision control with many usability features found in other git frontends like Gitlab, Github, Gogs, and many others.

- From here we want to add our SSH key to our account in Gitea. Grab the key in the clipboard: `cat /home/user/.ssh/id_rsa.pub` and paste it as an SSH key in Gitea under the account settings.

- **Git and Artifact Repository is installed.**

## Gitea Runners

Gitea has the ability to support running actions based on events that have occured in its environment (e.g. a push event.) To do this, you have to register runners, which are agents that run from a container, VM, or bare-metal system and can run commands and produce output as instructed by the runner descriptors in each repository.

In a later page, we'll describe how to register a runner and how to use the runner to automatically build and deploy a static docusaurus system-manual site for the system we're building.

## Revision Control Is Here!

Going forward, we now have working revision control. This means that we'll start to store all of our environment build, descriptions, configurations, and other artifacts in this repository so that we have provenance and posterity for all changes.