---
sidebar_position: 7
title: Baselined with CICD
---

:::danger Incomplete

All of the documents in GODS documentation are currently being rewritten.

:::

## Overview

We now have DNS, HTTPS, and Git running. While these are critical and tightly bound services that can't be blindly taken down and brought back without care, we're going to put their configuration into Gitea and enable updating them with CICD. 

Making updates to these services should either be a well defined process (adding dnsmasq hosts) or taken with great care and understanding of how their parts work. In other words, when something goes wrong, the maintainer should know how to start each of the services from scratch.

The good part of this is that you've documented the process (or copied the GODS documentation) to rebuild the core services. Any specific configurations would also have been stored into Gitea (which is backed up). Worst case scenario, if you don't have access to Gitea or its backups, you usually can recover quite a bit from a developer's repo clone. (This kind of recovery actually saved Pixar in a weird turn of events.)

## DNS/HTTPS/Git Availability Is _Important_

Remember:

- Everything depends on DNS, so if DNS goes down you can't build docker images that depend on looking up `hub.docker.com` or `git.lab`. You also can't access your git repositories or password manager.

- Most things depend on HTTPS and Host based reverse proxy routing. Luckily, you should still be able to access Gitea repos via SSH.

- Local artifacts (primarily container images) are not accessible if Gitea or `git.lab` is not accessible.

If you blindly shutdown DNS or Gitea and try to rebuild those images without understanding the issue, you'll find yourself in a catch 22 of "I need a chicken to lay the egg." ... This is the whole point of the GODS effort ... to document the order of events if you get stuck in this position.

### Reviewing Restarting Initial Services

To quickly summarize rebuilding the initial services without all the background and details:

1. Configure an external DNS in `/etc/resolv.conf` to get `dnsmasq_svc` rebuilt and running.
2. Reconfigure `/etc/resolv.conf` to point to `dnsmasq_svc` and then (optionally build) and start up `caddy_svc`.
3. Finally, you can (optionally rebuild and) start the `gitea_svc` as well as any required Gitea runner services.

In most cases, you should have all of the container images already cached and due to the dependencies defined in the docker compose yaml, you should be able to automatically start the _initial_ services by simply running:

```sh
cd /opt/services/lab_services-config/
docker compose -f inital-docker-compose.yml up -d
```

## Organizing Service With `include`

One great feature introduced into Docker Compose v2 is the `include` directive. This allows us to keep each of our services in separate YAML files, but include them into aggregate YAML files. We use 3 such files:

- `initial-docker-compose.yml` - All of the initial services included in a single file.
- `upstream-docker-compose.yml` - All of the non-initial services that are kept in the local Docker registry.
- `docker-compose.yml` - Both the initial and upstream services in a single file.

With this organization, we can implement automatic deployment by effectively running:

```sh
cd /opt/services/lab_services-config
docker compose -f initial-docker-compose.yml build
docker compose -f upstream-docker-compose.yml pull
docker compose up -d
```

This works because initial services are designed to be built on the _production server_ itself. The upstream services are designed to be pulled from Gitea. When we start up all of the services with the `up` command, it should only restart the services that have updated images available.

## Create The Repo w/ CICD Access

To implement the above, we want to store all of our docker compose service yaml files into a single lab/lab_services-config repository (that we've been building the whole time).

Within the `lab` organization, create a `lab_services-config` repo. Provide read-only access to the `cicd` user. Also, make sure that all of the folder and all files in `/opt/services` are owned by `cicd`:

```sh
sudo chown -R cicd /opt/services
```

Following this, you'll want to initialize the git repo in `/opt/services/lab_services-config` and assign the origin to the `lab/lab_services-config` repository.

## Define A Workflow

`.gitea/workflow/deploy.yml`:

```yaml
name: initial
run-name: ${{ gitea.actor }} is deploying lab/services updates.

on:
  push: 
    branches: [deploy]

jobs:
  build-oci:
    runs-on: [system]
    steps:

    - name: Check out repository code
      uses: https://git.lab/actions/checkout@v4

    - name: Dump environment variables
      run: env

    # Assumed that /opt/services is pre-created and owned by cicd.
    # Assumed that cicd has run docker login on destination machine.
    - name: Deploy system_manual image
      run: |
        ls && \
        ssh -p 2222 -o StrictHostKeyChecking=no cicd@www.lab \
          /bin/sh < rollout.sh
```

This workflow checks out the repository and remotely executes the contents of `rollout.sh` to fetch the repository and any updates into the _production server_ directly. Once the repository is copied, it executes `./do rollout` for it to run its own `docker compose` commands to update itself appropriately.

## Using The Workflow

<!-- TODO: Test these! -->

### Update DNS Hosts

- Clone `lab/lab_services-config` repo.
- Make changes to `dnsmasq_svc` for `extra_hosts`.
- Test your changes.
- Add/Commit/Push changes to main branch.
- `./do deploy` to merge and push changes into deploy branch.
- See changes in `dnsmasq_svc` automatically deployed in minutes.







