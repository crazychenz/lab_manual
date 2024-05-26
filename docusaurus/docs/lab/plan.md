---
sidebar_position: 1
title: Plan
---

:::danger Incomplete

All of the documents in GODS documentation are currently being rewritten.

:::

To begin, *every* project starts with a plan and the plan *always* changes. Here is my plan...

## Description

The following pages describe a process that I've been developing that I call a GitOps Driven Stack (GODS). GODS is an attempt to document a process to initialize a development environment system setup that hits (IMHO) a sweet spot between simplicity, realistic complexity, security, and functionality all while practicing a modest level of good practices.

In more plain terms: Our goal is to have a Developer Workstation (DD) environment where we can develop and test with docker and docker compose (or whatever we want). Once we're happy with our changes, we perform a `git push` (to a specific branch) to trigger the automatic CI/CD process deploy our updates to our K8s machine (KD). (All done completely offline.)

A future goal or deliverable of the GODS effort is to have a turn key solution for installing everything at once (similar to the classic LAMP software stack), but for a more generic and comprehensive development environment. Before we get to a fully automated setup, perhaps a manual process with many opportunities for specific situational tweaks is a better place to start.

## Assumptions and Constraints

Before we begin, I do believe I'm placing a number of uncommon assumptions and constraints upon myself that'll make you go "Why?" when you see some of the complexity I've integrated into the process.

- **Clear demarcation between online and offline.** - We should be able to rebuild our environment up to the point where we can fetch and clone from our Git instance (i.e. Gitea). This means having the bare minimum packages required to install K8s, Dnsmasq, Caddy, and Gitea. To clarify, I do not want to assume I always have internet connection. I want to be able to, without issue, get my GODS environment up, running, building, and hosting new applications updates while over the Atlantic Ocean.

- **Not everything is K8s** - While you'll notice that I make use of K8s in this configuration, it is _not_ a high availability cluster. In this environment, I use K8s as a replacement for the docker runtime for 2 reasons.

  1. Docker compose is a great tool for testing small cohesive applications in isolation, but when you begin to build a bigger system that you want to manage via GitOps with high fidelity, K8s is sort of dominant in the area.

  2. I work in a lab environment that is a mix of bare metal platforms, virtual machines, containers, windows, linux, macos, android, and others. The diversity of technology we want to be able to spin up forbids us from thinking in terms of "cloud" and IaaS. Hence, we're using K8s to manage what we can, but the services within K8s must provide functionality to non-cloud-able applications.

## Overview

When I refer to a _machine_, I intend to mean an environment with its own kernel. This could be a bare metal platform or a virtual machine. (It does not however include containers.)

There are 3 different machine configurations that I'll be referring to:

- **Online Dev (OD)**: The configuration that is connected to the internet. Think of this as a desktop or workstation at that has a stable internet connection.
- **Docker Dev (DD)**: The configuration that has docker installed. Think of this as a developer workstation that is in a laptop or isolated environment.
- **K8s Dev (KD)**: The configuration that has K8s installed. Think of this as a server for hosting applications and services.

Note: All of these can be the same machine.

There are also 3 different _essential_ services. These include:

- **DNS** - because *everything* needs hostnames (implemented by `dnsmasq`).
- **CA & HTTPS** - for reverse proxies, because *almost everything* needs HTTPS (implemented by `caddy`).
- **Git & Artifact Repo** - to enable configuration management and GitOps (implemented by Gitea).

For all machine environments, I'll be using Debian 12 as the base operating system.

## The Plan

1. Establish a baseline

    1. Install an OS (e.g. Debian) and relevant applications for the Online Dev, Docker Dev, and K8s Dev.
    2. Fetch a copy of the `lab_essentials` git repository.
    3. Collect the critical packages and build the `critical_pkgs.tar` file in Online Dev.
    4. Build the essential service container images on Docker Dev.
    5. Import the critical and essential service container images into K8s.
    6. Apply essential service manifests to K8s on K8s Dev machine.

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

Every time I've gone through this process, I've done it slightly different and the implementation has really been the only _documentation_ that I have of what I've done. The lack of documentation, in general, is because the product I intend to the develop is the focus of my documentation efforts, not the system that it was developed on. So we're going to fix that as a gap here.

### Self-Hosted Resources

The GODS process also depends solely on self-hosted software. As someone who works largely in areas with poor or no internet connection, part of remaining a highly available (local development) system, I don't want to depend on external services like public DNS, package repositories, git hosts, and the like. Note: We very much depend on external sources for the setup, but once we're running we should be able to go into Airplane mode without any issues or interruptions.

### Knowledge Sharing

Often I find peers either not following good practices, depending on external services, or depending on external administrators that are more simply self-managed than they know. There is nothing wrong with working through external services, but only if that is a deliberate decision.

Providing a baseline for a decent developer friendly and functional setup is key to helping others (and my future self) keep their developer system baselines out of the usual non-repeatable or adhoc installation slog.

### Probably Not For Most

Most folks that have continuous access to fast internet or even intermittent access to fast internet may get quicker success out of using professionally hosted services (GitHub, public cloud services, etc). This is a perfectly reasonable way to go if it works for you and fits within your budget. I personally hate giving companies my copyrighted material, intellectual property, and other creative works to do what they will when it isn't necessary.

<!-- **Online Dev**

1. Configure a machine for the collection of critical packages and files. I recommend a modern version of Debian.

2. Install openssh, sudo, git. Add the non-root user to the sudo group. (Optionally install vim, tmux).

3. `git clone` the `lab_essentials` repository.

4. Install docker from scripts in repo. Add non-root user to docker group.

5. Run the collection process to collect all of the baseline files.

6. Move the critical_pkgs.tar to Docker Dev.

**Docker Dev**

1. Configure a machine for the construction/building of container images. I recommend a modern version of Debian.

2. Install openssh, sudo, git. Add the non-root user to the sudo group. (Optionally install vim, tmux).

3. `git clone` the `lab_essentials` repository.

4. Install docker from scripts in repo. Add non-root user to docker group.

5. Build baseline images.

**K8s Dev**

1. Configure a machine for the hosting of container images (and other various state). I recommend a modern version of Debian.

2. Install openssh, sudo, git. Add the non-root user to the sudo group.

3. `git clone` the `lab_essentials` repository.

4. Install k3s

5. Import baseline images

6. Apply manifests -->

## Volumes


