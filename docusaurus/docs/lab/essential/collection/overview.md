---
sidebar_position: 1
title: Collection
---

:::danger Incomplete

This document is not yet updated.

:::

## Overview

The process for bootstrapping our GODS environment involves 3 phases:

- **Collection** of critical packages to build and import for minimal GitOps functionality.
- **Building** of various docker images with the critical packages from our development environment.
- **Deployment** of the essential services in an initial configuration before bootstrapping.

This section breaks down what we're doing with the collection. In general, we're grabbing:

- Alpine packages needed to all of the package manager packages that we need to build a DNS docker image, a docker image that includes the modern docker-ce packages for Debian.

