
# TODO: Copy and Deploy Manual

## Overview

system_manual build workflow:
on k8s: docker compose run act_runner
on dev: docker compose up authorbuild, write code/docs, test
on dev: git add/commit/push/deploy
on k8s: runner: does clone/build/push (with branch-commit-datetime tag)
on k8s: runner: tells flux to reconcile via ssh (i.e. hurry up)
on k8s: flux image scanner detects new image
on k8s: flux image policy choses the newest image
on k8s: flux image update writes the new tag to the manual manifest in k3s.vinnie.work-config
on k8s: flux source controller detects source update and updates k8s state
on k8s: Manual updated

Recommended to use `${GIT_BRANCH}-${GIT_SHA:0:7}-$(date +%Y%m%d%H%M%S)` for dev tagging.

## CI Setup

Assuming the gitea_sys_runner is already running ...

1. Obtain copy of manual.

```sh
git clone https://github.com/crazychenz/lab_manual.git
```

2. Create manual repo in git.lab (via browser).

3. Enable Actions in manual repo in git.lab (via browser).

4. Add image repo secrets: GITEADOCKER_USERNAME, GITEADOCKER_TOKEN (via browser).

5. Commit workflow yaml to manual repo.

```yaml
name: manuals
run-name: ${{ gitea.actor }} is building lab/manuals image.

on:
  push: 
    branches: [deploy]

jobs:
  build-oci:
    runs-on: [nodejs,docker]
    steps:

    - name: Check out repository code
      uses: https://git.lab/actions/checkout@v4

    #- name: Dump environment variables
    #  run: env

    - name: Login to Gitea Docker Registry
      uses: https://git.lab/docker/login-action@v3
      with:
        registry: git.lab
        username: ${{ secrets.GITEADOCKER_USERNAME }}
        password: ${{ secrets.GITEADOCKER_TOKEN }}

    - name: Build & push manual image
      run: ./do cicd

    # TODO: Tell flux to do its thing
    #- name: Deploy system_manual image
    #  run: 
```

6. Push updates to deploy branch to activate workflow.

```sh
./do deploy
```

## Flux Terminology

- GitRepository Object - Points to source repo
- Kustomization Object - Points to kustomization.yaml in source repo
- ImageRepository Object - Points to image registry for tag scanning
- ImagePolicy Object - Specification for ImageRepository tag selection.
- ImageUpdateAutomation - Specify manifest source to update with replacement tag.





## Setup Manifests

```sh
# ImageRepository - To scan for image tags.
flux create image repository lab-manual-img-repo \
--image=git.lab/lab/manual \
--interval=5m \
--export > lab-manual-flux-image-registry.yaml
```

```sh
# Create image policy for tag selection
flux create image policy lab-manual-img-select-policy \
--image-ref=lab-manual-img-repo \
--select-numeric=asc \
--filter-regex='^deploy-[a-fA-F0-9]+-(?P<ts>.*)' \
--filter-extract='$ts' \
--export > lab-manual-flux-image-select-policy.yaml
```

```sh
# GitRepository Pointer
# flux create source git <name>
flux create source git k8s-config-git-repo \
  --url=https://git.lab/lab/k8s-config \
  --branch=deploy \
  --interval=1m \
  --export > k8s-config-flux-git-repo.yaml
```

```sh
# Kustomization - Path to kustomize manifests in GitRepository
# flux create kustomization <name>
flux create kustomization lab-manual-kustomize-manifest \
  --target-namespace=default \
  --source=k8s-config-git-repo \
  --path="./services/lab-manual" \
  --prune=true \
  --wait=true \
  --interval=30m \
  --retry-interval=2m \
  --health-check-timeout=3m \
  --export > lab-manual-flux-kustomization.yaml
```

```sh
# ImageUpdateAutomation - Update all the marked things in git-repo-ref/git-repo-path
# This object points to manifests (e.g. Deployment) that contain the $imagepolicy marker.
# flux create image update <ImageUpdateAutomation Name>
flux create image update lab-manual-image-tag-updater \
--interval=30m \
--git-repo-ref=k8s-config-git-repo \
--git-repo-path="./services/lab-manual" \
--checkout-branch=deploy \
--push-branch=deploy \
--author-name=fluxcdbot \
--author-email=fluxcdbot@lab \
--commit-template="{{range .Changed.Changes}}{{print .OldValue}} -> {{println .NewValue}}{{end}}" \
--export > lab-manual-flux-image-tag-updater.yaml
```








```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: podinfo
  namespace: default
spec:
  selector:
    matchLabels:
      app: podinfo
  template:
    metadata:
      labels:
        app: podinfo
    spec:
      containers:
        - name: podinfod
          # {"$imagepolicy": "<policy-namespace>:<policy-name>"}
          # {"$imagepolicy": "<policy-namespace>:<policy-name>:tag"}
          # {"$imagepolicy": "<policy-namespace>:<policy-name>:name"}
          image: ghcr.io/stefanprodan/podinfo:5.0.0 # {"$imagepolicy": "flux-system:podinfo"}
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 9898
              protocol: TCP
```