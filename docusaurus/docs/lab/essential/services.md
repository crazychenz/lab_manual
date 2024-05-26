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

Ensure you've cloned the repository and are within its top folder:

```sh
git clone https://github.com/crazychenz/lab_essential.git
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
./collect-essential_pkgs.sh
```

This will generate a `essential_pkgs_install.sh` file that you'll need to copy to a Developer machine or K8S machine that has no internet.

```sh
scp essential_pkgs_install.sh user@dockerdevhost:/home/user/
```

## Building

If no internet on the docker build machine, install docker from offline.

```sh
cd /opt/imports/essential_pkgs/lab_essential/services
sudo ./install-docker-offline.sh
newgrp docker
```

From a machine with docker run `essential_pkgs_install.sh` script. Once the essential packages have been unpacked, you can remove the install script (or squirrel it away where its not taking up valuable space). Then, enter the `services` folder to begin building the rest of the essential container images.

```sh
cd /opt/imports/essential_pkgs/lab_essential/services
./build-images.sh
```

## Deployment

Ensure that the host SSH service is listening on port 2222.

Enter the `lab_essential/deployment` folder to install K3s, install essential images via K3s's CRI, and deploy the initial k8s GitOps services.

```sh
cd /opt/imports/essential_pkgs/lab_essential/deployment
sudo ./install-k3s.sh
sudo ./import-cri-images.sh
./deploy-services.sh
```

Optionally enable user access to `crictl` with:

```sh
sudo groupadd containerd
sudo chgrp containerd /var/run/containerd/containerd.sock
sudo adduser cicd containerd
```

## DNS Setup

Test that DNS is working from dnsmasq.

```sh
nslookup git.lab 192.168.1.5
curl -k https://git.lab
```

Change /etc/resolv.conf to non-localhost interface IP (e.g. 192.168.1.5) on k8s node. Verify coredns is reporting from dnsmasq. Do a `kubectl rollout reset ...` if not.

**Note:** You can not use localhost DNS because a docker build would not be able to access the correct network namespace without running network host mode.

## Install Caddy Certificate in k8s node.

```sh
sudo curl -k https://tls.lab/certs/root.crt \
  -o /usr/local/share/ca-certificates/lab-root.crt
sudo update-ca-certificates

# Restart docker (if installed) for the update to take effect
sudo systemctl restart docker
docker login -u cicd git.lab
```

## Get-All

```sh
sudo tar --transform='s/get-all-amd64-linux/kubectl-get_all/' \
  -xf /opt/imports/essential_pkgs/github/ketall/get-all-amd64-linux.tar.gz \
  -C /usr/local/bin/ get-all-amd64-linux
```

Test with: `kubectl get-all`

## Kubectl Autocomplete

```
echo "source <(kubectl completion bash)" >> ~/.bashrc
echo "alias kc=kubectl" >> ~/.bashrc
echo "complete -o default -F __start_kubectl kc" >> ~/.bashrc
```

## Gitea Setup

Do defaults
Create `cicd` user
`ssh-keygen`
add public ssh key to gitea
Create `lab` organization

**Note:** From this point on, we'll be saving new docker images to gitea.

## Install docker

The options as I see them:

- ~Build/push from dev.~ ... no.
  - We'll never know if its repeatable.
- ~Build/push from runner on dev.~ ... no.
  - Dev machine should be more volatile than a CI should be.
- ~Build/push from runner on dedicated CI.~ ... no.
  - This wastes my limited memory and compute resources when not building.
- ~Build/push from runner on k8s cluster.~ ... no.
  - This presents to many security implications and complex alternatives.
- Build/push from runner in docker on k8s node (**not** in k8s). ... yes!

In our environment, I'm installing docker side by side with kubernetes. This side by side installation is purely so that I can make the most efficient use of the virtual machine memory. Given the correct resources, it is recommended that you host a dedicated CI server that has its own Docker daemon or other build support that is isolated from the "production" K8S server.

A couple important notes:

- Because we have docker installed in the k8s system, we could easily slip down the path of declaring a container privileged and volume mounting `/var/run/docker.sock` to permit Docker building and testing from a K8S managed container. Since this couples the K8S system and the Docker in a manner that is unnecessary for our purposes, by convention **we must never mount `/var/run/docker.sock` into a K8S managed container**. (Not to mention the security implications).

- The only real purpose of having Docker living in the K8S node is to host the Gitea Action Runner (`act_runner`) and potentially other CI related tasking. Docker is more than capable of managing this service itself. In the event we want to update the CI services, we can have something like Watchtower do the update, have Gitea Action Runner upgrade itself, or do a manual update when its required.

- Because the Docker Daemon exists for builds only, its likely to fill the available disk space quickly. It is recommended to have the local Docker image repo reside on its own volume to prevent K8s from failing to do development resources. Additionally, the docker cache should be pruned periodically to prevent manual pruning maintenance.

- If we deploy multiple K8S nodes, we can optionally spread the build load across the same K8S nodes if each of the nodes contain duplicates of the Gitea Action Runner images running the same labels.

To install docker on the node:

```sh
cd /opt/imports/essential_pkgs/lab_essential/services
sudo ./install-docker-offline.sh
newgrp docker
docker login -u cicd git.lab
```

## TODO: Deploy Gitea Action Runner

Fetch the runner token from Gitea. ("Site Administration -> Actions -> Runners -> Create new Runner")

Start the runner with Docker Compose.

```sh
cd /opt/imports/essential_pkgs/lab_essential/services
RUNNER_TOKEN="token goes here" docker compose up -d gitea_sys_runner
```

## FluxCD

Install flux onto system.

`sudo tar -xzof /opt/imports/essential_pkgs/github/fluxcd/flux_*_linux_amd64.tar.gz -C /usr/local/bin`

In our Gitea applications (https://git.lab), create `lab/flux-config` Gitea repo.

Check pre-installation conditions:

`KUBECONFIG=/etc/rancher/k3s/k3s.yaml flux check --pre`

Bootstrap flux:

```sh
KUBECONFIG=/etc/rancher/k3s/k3s.yaml \
flux bootstrap git \
  --url=ssh://git@git.lab/lab/flux-config \
  --branch=deploy \
  --private-key-file=/home/cicd/.ssh/id_rsa \
  --path=clusters/lab \
  --components-extra image-reflector-controller,image-automation-controller
```

Verify flux health with:

`KUBECONFIG=/etc/rancher/k3s/k3s.yaml flux check`
