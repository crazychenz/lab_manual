---
sidebar_position: 7
title: Baselined
---

## Initial Services Are *Actually* Important

We now have DNS, HTTPS, and Git running. These are critical and tightly bound services that can't be blindly taken down and brought back without care. Remember:

- Everything depends on DNS, so if DNS goes down you can't build docker images that depend on looking up `hub.docker.com` or `git.lab`. You also can't access your git repositories or password manager.

- Most things depend on HTTPS because everything uses Caddy for TLS termination or reverse proxy Host based routing. Without Caddy, you can't access `git.lab`.

- All local artifacts (primarily container images) are not accessible if Gitea or `git.lab` is not accessible.

## Restarting Initial Services

In a worst case scenario, you'll need to manually:

1. Configure an external DNS in `/etc/resolv.conf` to get `dnsmasq_svc` rebuilt and running.
2. Reconfigure `/etc/resolv.conf` to point to `dnsmasq_svc` and then (optionally build) and start up `caddy_svc`.
3. Finally, you can (optionally rebuild and) start the `gitea_svc` as well as any required Gitea runner services.

In most cases, you should have all of the container images already cached and due to the dependencies defined in the docker compose yaml, you should be able to automatically start the _initial_ services with:

```sh
cd /opt/services/lab_services-config/
docker compose -f inital-docker-compose.yml up -d
```

## Separating Initial From Others

Because of the criticality of these initial services:

- We **do** track the docker compose yaml and `contexts` data in revision control for configuration management purposes.
- We **do not** depend on their images only being built in a runner and pulled for updates.

Most other container image builds can be built in a Gitea runner and then simply pulled into the lab _production server_ from Gitea.

Its because of this separation that we have a `initial-docker-compose.yml` and a `upstream-docker-compose.yml` to aggregate our services. The `initial-docker-compose.yml` must always be able to use `docker compose build` locally on the server. The `upstream-docker-compose.yml` services should always use `docker compose build` in a runner or another machine and only ever be `docker compose pull`-ed into the lab _production server_.

For the sake of bringing everything together for **non-**`build`/`pull` operations, we have a `docker-compose.yml`.

## What's Next?

The next priority is documentation. In reality, documentation comes first and we should have been documenting everything up to this point (hopefully in Markdown) in our text editor of choice. Now we're going to take that existing documentation and put it in a presentable form.

Once the documentation is presentable, we'll use it as the first Continuous Integration & Continuous Delivery (CICD) use case in our lab setup. This will involve registering Gitea runners, Gitea workflows, and building various Rube Goldberg machines to deliver the output to the _production server_. This process can then be rinse & repeated for any number of services or product workflows to get you on your way to full featured DevOps environment.

That said, we're now considering ourselves _baselined_ to a point where there isn't really a set of linear things to do from here. If you want to jump to setting up ansible, integrating security services instead, or developing product development workflow, go forth and conquer!






