---
sidebar_position: 2
title: Plan
---


:::danger Incomplete

This document is not yet written.

:::

## Overview

OK, plan:

- Create lab **VM** and install lab admin host **OS** [OS-Install](./initial/os_install)
- Install **DNS**, because *everything* needs hostnames. [dnsmasq](./initial/dnsmasq)
- Install a **CA & HTTPS** server for reverse proxies, because *almost everyting* needs HTTPS. [caddy](./initial/caddy)
- Install a **password manager**, because *everything* needs credentials. [vaultwarden](./initial/words)
- Install a **git and artifact repository** to enable configuration management and GitOps, because CM is *good practice*. [gitea](./initial/gitea)
- Install HTTPS hosted **manual** for the *whole system* that is managed by our DNS, CA, HTTPS, GIT, and Artifact Repo. [manual](./docs)

Once we're at the point that all of the above is complete:

- Redo everything so that its all either stored, managed, or DevOp-ed by itself ... for configuration management.
- Ensure there is a backup process and there is a tested restoration plan ... for posterity and availability.
- Add a process to verify the baseline of the system ... to notify and protect against misinformed administration.
- Add localized caches or mirrors ... to keep things running without internet.
- Add security products, like clamav, greenbones, and so forth ... to protect from outside attackers.
- Add centralized authentication, identity management, and auditing via FreeIPA, LDAP, syslogs, and so forth ... to protect from inside attackers.
- Add asymetric encryption mechanisms ... for long term confidentiality and integrity of audits and logs.

Now that we've baselined a *functional* system with *CM* and *true* **prescriptive** *security*, we start to evolve the system to meet our application specific development needs:

- Network management (VLANs, port security, firewalls)
- Virtualization management (Hypervisors, Shared Resources)
- File Sharing (NFS, Gluster, SFTP, CIFS)
- Third Party Tool Repositories and Installs
