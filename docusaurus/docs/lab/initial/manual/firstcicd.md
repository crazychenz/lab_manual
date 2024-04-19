---
sidebar_position: 40
title: Implementing Lab Manual CICD
draft: false
---

## Overview

At the point, its assumed that you've successfully:
- Setup and started a DNS, CA, HTTPS Service, Gitea, and a Gitea Runner.
- Setup, built, and deployed a Docusaurus instance via a Git Repo and Git Docker Registry.

With the runner up and running, our goal will be to setup our repository such that when we push updates to the `deploy` branch of its Git repo, it'll automatically build and deploy the site to the production server. Its recommended to use a non-`main` branch for this kind of behavior to discourage folks from being afraid of pushing updates and potentially messing up a deployed build. Developers should always be comfortable to commit, push, and then allow some brain rest before making the commitment to `deploy` the code.

The plan is to trigger an action when a `push` event occurs on the `deploy` branch. Our action will then:

1. Build the static-site docker image from the `gitea_sys_runner`.
2. Push the static-site docker image to the central Gitea Docker Registry.
3. Pull the static-site docker image to the production server (via SSH).
4. Restart the static-site docker image on the production server (via SSH).

**Note:** Since GitOps controls the configuration above the baseline system, it is accepted that some repositories will contain credentials or keys required for system automation. These configuration specific repositories are kept separate from the source code repositories.

## The Action Descriptor

Action descriptors are very complex yaml's that ultimately are shell scripts with a set of conditions. You can read more about them in GitHub documentation. (_Most_ GitHub action fields are compatible with Gitea.)

Create the following yaml in the file path `.gitea/workflows/build-app.yml` from the top of the project folder (i.e. `/opt/manuals/system_manual`).

```yaml
name: system_manual
run-name: ${{ gitea.actor }} is building git.lab/lab/manuals image.

on:
  push: 
    branches: ['deploy']

jobs:
  build-oci:
    runs-on: [system,another]
    steps:

    - name: Check out repository code
      uses: https://git.lab/actions/checkout

    - name: Dump environment variables
      run: env

    - name: Build systems image
      run: ./do cicd

    - name: Rollout systems image in k3s.vinnie.work
      run: |
        ssh -o StrictHostKeyChecking=no \
          -i /home/cicd/.ssh/id_rsa cicd@k3s.vinnie.work \
          kubectl -n work-vinnie rollout restart deployment/work-vinnie-systems
```

In the above descriptor:

- We're triggered on `push` event to `deploy`.
- We checkout the relevant code into the working directory with the `uses: https://git.lab/actions/checkout` line.
- From the working directory, I dump the environment variable for logging and troubleshooting purposes.
- We then run our `./do` script's `cicd` target. If you recall, this is equivalent to `./do build && ./do push` in a single command.
- Finally, we pull and deploy the image via SSH on the production server. (Note: If there was more equity at stake, you'd want to add some unit testing between the build and the deployment.)


