## Test Deployment

- GitRepository Object - Points to source repo
- Kustomization Object - Points to kustomization.yaml in source repo
- ImageRepository Object - Points to image registry for tag scanning
- ImagePolicy Object - Specification for ImageRepository tag selection.
- ImageUpdateAutomation - Specify manifest source to update with replacement tag.

Recommended to use `${GIT_BRANCH}-${GIT_SHA:0:7}-$(date +%Y%m%d%H%M%S)` for dev tagging.

```sh
# GitRepository Pointer
# flux create source git <name>
flux create source git podinfo \
  --url=https://github.com/stefanprodan/podinfo \
  --branch=master \
  --interval=1m \
  --export > ./clusters/lab/podinfo-source.yaml
```

```sh
# Kustomization - Path to kustomize manifests in GitRepository
# flux create kustomization <name>
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

```sh
# ImageRepository - To scan for tags.
# flux create image repository <ImageRepository Name>
flux create image repository podinfo \
--image=ghcr.io/stefanprodan/podinfo \
--interval=5m \
--export > ./clusters/my-cluster/podinfo-registry.yaml
```

```sh
# Create image policy for tag selection
# flux create image policy <name>
flux create image policy podinfo \
--image-ref=podinfo \
--select-semver=5.0.x \
--export > ./clusters/my-cluster/podinfo-policy.yaml

flux create image policy <ImagePolicy Name> \
--image-ref=<ImageRepository Name> \
--select-numeric=asc \
--export > ./path/to/policyname-policy.yaml
```

```yaml
kind: ImagePolicy
metadata:
  name: <ImagePolicy Name>
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: <ImageRepository Name>
  filterTags:
    pattern: '^main-[a-fA-F0-9]+-(?P<ts>.*)'
    extract: '$ts'
  policy:
    numerical:
      order: asc
```

```sh
# ImageUpdateAutomation - Update all the marked things in git-repo-ref/git-repo-path
# This object points to manifests (e.g. Deployment) that contain the $imagepolicy marker.
# flux create image update <ImageUpdateAutomation Name>
flux create image update flux-system \
--interval=30m \
--git-repo-ref=flux-system \
--git-repo-path="./clusters/my-cluster" \
--checkout-branch=main \
--push-branch=main \
--author-name=fluxcdbot \
--author-email=fluxcdbot@users.noreply.github.com \
--commit-template="{{range .Changed.Changes}}{{print .OldValue}} -> {{println .NewValue}}{{end}}" \
--export > ./clusters/my-cluster/flux-system-automation.yaml

flux create image update  \
# How often to do things
--interval=30m \
# GitRepository to potentially be updated
--git-repo-ref=flux-system \
# Path to files to be scanned for updates
--git-repo-path="./clusters/my-cluster" \
# Branch to do scanning for updates on
--checkout-branch=main \
# Branch to commit updates to
--push-branch=main \
# Provenance
--author-name=fluxcdbot \
--author-email=fluxcdbot@users.noreply.github.com \
# Commit message (Go Templating?)
--commit-template="{{range .Changed.Changes}}{{print .OldValue}} -> {{println .NewValue}}{{end}}" \
--export > ./clusters/my-cluster/flux-system-automation.yaml
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

**Note:** With Flux image management, all `image:` field updates are dictated by the ImageRepository.


TODO:

https://fluxcd.io/flux/guides/image-update/



