---
sidebar_position: 1
title: Approach
draft: true
---

:::danger Incomplete

This document is not yet written.

:::

- Contents
- Synopsis
- Description
- Reasoning
- Procedure
- Resources

Below we'll go over my approach to our system end goals and some of my thoughts surrounding those approaches.

Below we'll go over the purpose and use of each of the following tools:

- _Hypervisor_ - qemu, VirtualBox
- _Container Runtime_ - Docker
- _DNS_ - dnsmasq
- _Web Server_ - Caddy
- _Certificate Authority_ - Caddy / Smallstep
- _Authentication_ - FreeIPA
- _Password Manager_ - Vaultwarden
- _Storage_ - MinIO? NFS? Other?
- _Revision Control_ - Git / Gitea
- _Artifact Repository_ - Gitea
- _Manual Presenter_ - Docusaurus
- _Security Scanning_ - Greenbones, ClamAV
- _Backups_ - LVM Snapshots
- _Encrypted Backups_ - OpenSSL & Scripts

The goal for this setup is to have as much of the configuration and baseline stored in git as the authoritative source of truth. This has the unfortunate side effect of preventing a straight forward install this than that. We'll need to install some tools partially and then return to them to integration our GitOps methodology.

In general, we'll focus on getting a base operating system with a git repository up first since this will remain our source of truth throughout the process. We'll then setup a pre-GitOps Vaultwarden and Docusaurus to assist with tracking everything. With those tools bootstrapped, we should then be able to git control everything else. Its worth noting here that we're deliberately not going to GitOps the OS setup and storage. These are things that could be handled by a Kubernetes or other orchestration ecosystem. In our environment, K8s would be vastly over engineering for our way more simple requirements.

## The Plan

1. Virtual Machine (if desired)
2. Storage Setup / Backup Strategy
3. OS Install (Ubuntu LTS) and Container Runtime (Docker)
4. Initial DNS (dnsmasq)
5. Initial Web Server & Certificate Authority (Docker)
6. Initial Vaultwarden (Docker)
7. Initial Gitea (Docker)
8. Docusaurus (Docker)
9. Final DNS
10. Final Web Server & Certificate Authority (Docker)
11. Final Vaultwarden (Docker)
12. Final Gitea (Docker)

13. FreeIPA (Docker)
14. Security Scanning (Docker)
15. Encrypted External Backups (Docker)

### Plans Notes:

- Virtual Machine is the _hardware_ foundation.
- Storage setup is the partition and volume management.
- OS install and container runtime is the application management.
- DNS is required next because all other _priority_ items require DNS.
- Caddy is required after DNS because its required for all web apps as the CA and primary reverse proxy router.
- Vaultwarden is required next because we need to track credentials ASAP and its has no dependents.
- Gitea is next and is the _core_ of the GitOps system. It requires all the the things previously setup.
- Docusaurus is the next item to verify the correct operation of GitOps on an item with low initial impact.
- DNS, Caddy, Vaultwarden, and Gitea GitOps bootstrap.

- TODO: Add FreeIPA
- TODO: Add Security SCanning
- TODO: Add Backups and Snapshots
- TODO: Roll our own encrypted external backups

## Documentation

As a principal, the first thing you should establish with _any_ project is a location to keep the various type of documentation that need to be tracked. Considering that documentation is a complicated _thing_, we'll start by saying that we need to primarily concern ourselves with the types of data that we consider documentation. Along with these types of documentation, we'll also consider the right tool to store or present the data type.

- Sensitive Data (e.g. credentials) - Vaultwarden (Password Manager)
- Decisions Data (e.g. baselines and configuration) - Git/Gitea (Revision Control)
- Artifact Data (e.g. binaries, images, and so forth) - Gitea (Revision Control / Artifact Store)
- Human Readable Data (e.g. manuals) - Docusaurus

Note: I acknowledge that its weird to consider a binary or artifact as a piece of documentation. But I will argue, what is the use of referencing some binary in a manual if the user can't actually get to it. In another example, is an artifact in a museum not a form of historical documentation?

Caution: User data (and tenant project documentation) is not documentation or artifacts. User data is kept available via sufficient backup/snapshots strategies. In other words, GitOps is not responsible for storing user data itself. GitOps _is_ responsible for tracking the scripts required to kick off backups though.

## Base OS & Storage

To run anything, we'll need a fresh system (or array of systems) to load our services on to. Any operating system would likely work, but due to the community support and availability, Ubuntu (or other Debian derivative) is my preferred option. It's advisable to always lean on LTS versions of upstream releases unless you have an explicit reason to use another version. In my case, Ubuntu Jammy 22.04.3 is the current sweet spot.

You'll always want to have a desktop manager of some kind installed onto the base OS of the machine, presuming there is ever going to be a monitor/keyboard/mouse attached. The sole purpose of of desktop manager on a server enables you to have the ability, as an administrator, to lock the machine with on-demand tasks running while offline! Many times I've been on servers that only have a getty console. With the traditional console, you have to manually shove tasks into the background as `disown`ed or `nohup`ed to prevent them from dying when you logout to lock the screen. With a desktop manager, its usually Win+L and the screen is locked, allowing me my required bio breaks without any stress. Note: If you have some fancy remote KVM or ZeroClient capability with its own authentication, then this paragraph becomes moot.

Btrfs? Storage is where I've often gotten caught up many times in the past. There are a number of methods for partitioning drives to meet a myriad of use cases. After dealing with this kind of thing for over 20 years, I think the best small use case is LVM+EXT. Btrfs is a great file system, but sort of locks you into btrfs ecosystem. If you work in an engineering environment like I do where we're always needing to try out new filesystems, I prefer to handle LVM in a way that is 100% decoupled from the filesystem I intend to use.

ZFS? Some folks really like to lean into ZFS. This is not advisable from a production standpoint because its not upstreamed into the Linux kernel due to a number of license, copyright, and patent issues. Sure, its completely useable out of tree, but now your defeating the whole purpose of using an LTS kernel/distro release to begin with.

XFS? Ext4 vs XFS is really a preference. XFS boasts a focus on parallelization which is likely much better for performance in a OpenStack environment, but for the community support, maturity, and security, you can't do much better than ext3 or ext4. Ext4 has been in the wild and stable since 2008 (14 years at the time of this writing).

MBR? Whether you are going to use a MBR or GPT partitioning scheme really comes down to your BIOS _and_ the BIOS of any recovery hardware you intent to have available. If all of your hardware is capable of booting GPT, use GPT. If you have ancient hardware (usually for specialized interfaces no longer supported), you may want to consider MBR.

I prefer to use GPT partition scheme with the standard UEFI, boot, and a 64GB Ext4 partition for the base OS (likely using Grub, but I don't care what boot loader is used.) The rest of the storage is partitioned as a LVM managed partition and added to the system as a physical volume (PV) device. You can also opt to have another non-LVM partition created for recovery or troubleshooting space in the event you can't mount the LVM logical volumes. This space could be used for extra tooling, system logs, or backups/snapshots of the 64GB OS. For my purposes, I'm going to assume LVM is flawless and depend on **real** backups for recovery.

- Partition Type: GPT w/ UEFI
- Primary Partition: 64 GB - Ubuntu Jammy 22.04.3 (LTS)
- Secondary Storage: LVM Physical Volume
- Operating System: Ubuntu Jammy 22.04.3 (LTS/Desktop)
- Logical Volumes
  - Gitea Repositories (i.e. special static file storage)
  - Service State Data (i.e. space for state information)
  - Shared File Storage (i.e. tenant project files)
  - Static File Storage (i.e. Mirrors and Versioned Binaries)
  - Backup Storage - External storage, usually offsite.

## Web Servers, Certificates, and PKI Oh My!

Its important to preface that humans in the context of this document are in reference to users that are literate but without super human abilities. Super humans are able to track many variables and calculate complex equations without error. _Normal_ humans miss subtle details, make mistakes, and interpret the same line of text differently from reading to reading. And in this context, end-user is synonymous to human.

When presenting solutions that will be end-user accessible, we should standardize the way that is presented. In short, everything should be a web application where applicable. This also means that we need a consistent web server and PKI infrastructure to secure (and power) the web server's HTTPS protocol. For this particular requirement, we'll use Caddy for its simplicity in setting up a CA, TLS certificates, configuration of reverse proxies, and configurations of statically hosted files.

## Security

Security sucks, especially when not appropriately prescribed to the environments threat level. Either way, security is something to be mindful of and incorporate into GitOps. Some egotistical IT folks like to fancy themselves a DevSecOps person. All hogwash ... its merely a number of mitigations or reactions to malicious cyber actors or accidental/negligent behaviors.

In our case, we'd like to design in the ability to perform:

- Basic Virus Scanning (retroactive) - ClamAV
- User Auditing (retroactive)
- Centralized Authentication / Authorization (proactive) - FreeIPA
- Vulnerability Scanning (proactive) - Greenbones, OpenVAS

We of course should manage our base operating system (GNU/Linux) as well with discretionary access controls. Mandatory access controls (AppArmour, SELinux) are over-engineered for our purposes, but we'll need to be aware of them since they are built into all modern distributions.
