---
sidebar_position: 1
title: Plan
---


Whether we admit it or not, *every* project starts with a plan and the plan *always* changes. Here is my plan...

## Description

The following pages describe a process that I've been developing that I call a GitOps Driven Stack (GODS). GODS is an attempt to document a process to initialize a development environment system setup that hits (IMHO) a sweet spot between simplicity, realistic complexity, security, and functionality all while practicing a modest level of good practices.

A future goal or deliverable of the GODS effort is to have a turn key solution for installing everything at once (similar to the classic LAMP software stack), but for a more generic and comprehensive development environment. Before we get to a fully automated setup, perhaps a manual process with many oppurtunities for situationally specific tweaks is a better place to start.

## Overview

1. Create an initial environment that gets us to the starting line.

    1. Create lab **VM** and [install lab administration host **OS**](./initial/os_install) with Docker using Compose v2.

    2. [Install all of the initial services](./initial/services/overview) required to bootstrap our baseline environment.

        1. Install **DNS**, because *everything* needs hostnames.\
        <!-- [dnsmasq](./initial/services/dnsmasq) -->
        2. Install a **CA & HTTPS** server for reverse proxies, because *almost everyting* needs HTTPS.
        <!-- [caddy](./initial/services/caddy) -->
        3. Install a **password manager**, because *everything* needs credentials.
        <!-- [vaultwarden](./initial/services/words) -->
        4. Install a **git and artifact repository** to enable configuration management and GitOps, because CM is *good practice*.
        <!-- [gitea](./initial/services/gitea) -->

    3. Install HTTPS hosted **manual** for the *whole system* that is managed by our DNS, CA, HTTPS, GIT, and Artifact Repo.
    <!-- [manual](./docs) -->

2. Ensure the baseline is stored, managed, or controlled by GitOps. The is essential for good configuration management.

3. Apply processes to ensure our system has availability, integrity, and confidentiality to an appropriately prescriptive degree.

    - Ensure there is a backup process and there is a tested restoration plan ... for posterity and availability.
    - Add a process to verify the baseline of the system ... to notify and protect against misinformed administration.
    - Add localized caches or mirrors ... to keep things running without internet.
    - Add security products, like clamav, greenbones, and so forth ... to protect from outside attackers.
    - Add centralized authentication, identity management, and auditing via FreeIPA, LDAP, syslogs, and so forth ... to protect from inside attackers.
    - Add asymetric encryption mechanisms ... for long term confidentiality and integrity of audits and logs.

4. Add utility to allow the secure scalability and flexibility of the system as required by the application specific purposes of the system.

    - Network management (VLANs, port security, firewalls)
    - Virtualization management (Hypervisors, Shared Resources)
    - File Sharing (NFS, Gluster, SFTP, CIFS)
    - Third Party Tool Repositories and Installs

## Reasoning - Why do this at all? 

### Documenting The System, Not The Product

I've been required to develop similar environments several times now. Each time I sit down to start a new project or lab environment to support a particular project, I have to revisit what I've done before:

- How do I setup a DNS server again?
- How do I setup an artifact repository again?
- How do I ensure a workflow is executed when I commit/push changes?
- ... and so on and so forth.

Everytime I've gone through this process, I've done it slightly different and the implementation has really been the only _documentation_ that I have of what I've done. The lack of documentation, in general, is because the product I intend to the develop is the focus of my documentation efforts, not the system that it was developed on. So we're going to fix that as a gap here.

### Self-Hosted Resources

The GODS process also depends solely on self-hosted software. As someone who works largely in areas with poor or no internet connection, part of remaining a highly available (local development) system, I don't want to depend on external services like public DNS, package repositories, git hosts, and the like. Note: We very much depend on external sources for the setup, but once we're running we should be able to go into Airplane mode without any issues or interruptions.

### Knowledge Sharing

Often I find peers either not following good practices, depending on external services, or depending on external administrators that are more simply self-managed than they know. There is nothing wrong with working through external services, but only if that is a deliberate decision.

Providing a baseline for a decent developer friendly and functional setup is key to helping others (and my future self) keep their developer system baselines out of the usual non-repeatable or adhoc installation slog.

### Probably Not For Most

Most folks that have continuous access to fast internet or even intermitten access to fast internet may get quicker success out of using professionally hosted services (GitHub, public cloud services, etc). This is a perfectly reasonable way to go if it works for you and fits within your budget. I personally hate giving companies my copyrighted material, intellectual property, and other creative works to do what they will when it isn't necessary.