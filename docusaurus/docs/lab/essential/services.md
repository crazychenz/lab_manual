---
sidebar_position: 3
title: Essential Services
---

As part of the GODS setup, we need to initialize what I refer to as the essential services.

- Container Runtime
- DNS
- CA & HTTPS
- Git & Artifact Repositories

In general, there are 3 phases to accomplish this:

- **Collection** of critical packages to build and import for minimal GitOps functionality.
- **Building** of various docker images with the critical packages from our development environment.
- **Deployment** of the essential services in an initial configuration before bootstrapping.

All of these are captured in the [`lab_essentials`](https://github.com/crazychenz/lab_essential) repository.

## Collection

Ensure you've cloned the repository:

```sh
git clone https://github.com/crazychenz/lab_essential.git
```

Change your working folder to `lab_essential`:

```sh
cd lab_essential
```

If you haven't already installed docker, you can setup your (Debian) apt environment by running:

```sh
sudo ./install-docker.sh
newgrp docker
```

With your new found docker powers, you can now run the collection process.

```sh
cd collector
./collect-critical_pkgs.sh
```

This will generate a `critical_pkgs_install.sh` file that you'll need to move to your Docker Dev machine.

```sh
scp critical_pkgs_install.sh user@dockerdevhost:/home/user/
```

## Building

From the Docker Dev machine, run `critical_pkgs_install.sh` script.

Once the critical packages have been unpacked, enter the `services` folder.

Optionally install docker while offline (for Debian)

```sh
cd /opt/imports/essential_pkgs/lab_essential/services
sudo ./install-docker-offline.sh
newgrp docker
```

Begin building the essential images.

```sh
cd /opt/imports/essential_pkgs/lab_essential/services
./build-images.sh
```

The `build-images.sh` script will output an `essential_pkgs_install.sh` file that needs to be moved to the K8s Dev machine.

```sh
scp essential_pkgs_install.sh user@k8sdevhost:/home/user/
```

## Deployment

Ensure that the host SSH service is listening on port 2222.

From the K8s Dev machine, run `essential_pkgs_install.sh` script.

Once the critical packages have been unpacked, enter the `deployment` folder.

```sh
cd /opt/imports/essential_pkgs/lab_essential/deployment
```

Once the essential packages have been unpacked, you can go into the `deployment` folder of the lab_essential repo to optionally install K3s while offline or begin importing the essential images.

<!-- TODO: Finish these scripts. -->

```sh
sudo ./k3s-install.sh
sudo ./import-images.sh
./deploy-services.sh
```

## Test services

```sh
nslookup git.lab 192.168.1.5
curl -k https://git.lab
```

## DNS Setup

Change /etc/resolv.conf to localhost or local IP on k8s node.

Verify coredns is reporting from dnsmasq. rollout reset if not.

## Get-All

```sh
sudo tar --transform='s/get-all-amd64-linux/kubectl-get_all/' \
  -xf /opt/imports/essential_pkgs/github/ketall/get-all-amd64-linux.tar.gz \
  -C /usr/local/bin/ get-all-amd64-linux
```

Test with: `kubectl get-all`

## Gitea Setup

Do defaults
Create `cicd` user
`ssh-keygen`
add ssh key to gitea
Create `lab` organization

## Flux

Install flux onto system.

`sudo tar -xzof /opt/imports/essential_pkgs/github/fluxcd/flux_*_linux_amd64.tar.gz -C /usr/local/bin`

Create `lab/flux-config` Gitea repo.

Check pre-installation conditions:

`KUBECONFIG=/etc/rancher/k3s/k3s.yaml flux check --pre`

Bootstrap flux:

```sh
KUBECONFIG=/etc/rancher/k3s/k3s.yaml \
flux bootstrap git \
  --url=ssh://git@git.lab/lab/flux-config \
  --branch=main \
  --private-key-file=/home/cicd/.ssh/id_rsa \
  --path=clusters/lab \
  --components-extra image-reflector-controller,image-automation-controller
```

Verify flux health with:

`KUBECONFIG=/etc/rancher/k3s/k3s.yaml flux check`

## Test Deployment

```sh
# Create a pointer to Git Repository
flux create source git podinfo \
  --url=https://github.com/stefanprodan/podinfo \
  --branch=master \
  --interval=1m \
  --export > ./clusters/lab/podinfo-source.yaml
```

```sh
# Create a monitored pointer to kustomize manifests in GitRepository
flux create kustomization podinfo \
  --target-namespace=default \
  --source=podinfo \
  --path="./kustomize" \
  --prune=true \
  --wait=true \
  --interval=30m \
  --retry-interval=2m \
  --health-check-timeout=3m \
  --export > ./clusters/lab/podinfo-kustomization.yaml
```

TODO:

https://fluxcd.io/flux/guides/image-update/
