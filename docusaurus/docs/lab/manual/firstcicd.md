---
sidebar_position: 40
title: Lab Manual CICD
draft: false
---

## Overview

At this point, its assumed that you've successfully:
- Setup and started a DNS, CA, HTTPS Service, Gitea, and a Gitea Runner.
- Setup, built, and deployed a Docusaurus instance via a Git Repo and Git Docker Registry.

With the runner up and running, our goal will be to setup our repository such that when we push updates to the `deploy` branch of its Git repo, it'll automatically build and deploy the site to the production server. Its recommended to use a non-`main` branch for this kind of behavior to discourage folks from being afraid of pushing updates and potentially messing up a deployed build. Developers should always be comfortable to commit, push, and then allow some brain rest before making the commitment to `deploy` the code.

The plan is to trigger an action when a `push` event occurs on the `deploy` branch. Our action will then:

1. Build the static-site docker image from the `gitea_sys_runner`.
2. Push the static-site docker image to the central Gitea Docker Registry.
3. Pull the static-site docker image to the production server (via SSH).
4. Restart the static-site docker image on the production server (via SSH).

**Note:** Since GitOps controls the configuration above the baseline system, it is accepted that some repositories will contain credentials or keys required for system automation. These configuration specific repositories are kept separate from the source code repositories. (By convention, all repositories that contain this kind of configuration information will be suffixed with `-config` to indicate their sensitivity and machine specific nature).

## Precondition For CICD Access

For our CICD process to succeed, we need to create a special user that it can operate as. By convention, I use `cicd` as the username (often with the UID 1000) for this purpose. 

In the Gitea Runner:

- `rootless` user should have access to the private SSH key for `cicd` so that it can login to the _production server_ (as `cicd`) to perform relevant operations.

In Gitea:

- Must have a `cicd` user with it's public SSH key registered for access.
- The `cicd` user should be given membership and read-only access to all repositories you plan for it to build.
- The `cicd` user must have access to push container images into its Docker registry. This is done at the organization packages level and may require creating a CICD team to give it membership of.
- The `cicd` Gitea login username/password must be included as Action-Runner secrets at the organization level.

In the _production server_:

- The `cicd` user must exist and have SSH keys enabled as well as it's public key within the `authorized_keys` SSH configuration.
- The `cicd` user must have  the `docker login` performed and saved within its profile.
- The `cicd` user must be in the `docker` group.
- The `cicd` user must have sufficient `sudo` permissions to accomplish its required actions.

Note: The `cicd` private and public keys as well as its username and password would be a good thing to store in the Vaultwarden for safe keeping and management.

## The Action Descriptor

Action descriptors are complex yaml's that ultimately are shell scripts with a set of conditions. You can read more about them in GitHub documentation. (_Most_ GitHub action fields are compatible with Gitea.)

Create the following yaml in the file path `.gitea/workflows/build-app.yml` from the top of the project folder (i.e. `/opt/manuals/system_manual`). Gitea will read all of the yaml files in `./gitea/workflows`, so you can really name the yaml file itself whatever you want.

```yaml
name: manuals
run-name: ${{ gitea.actor }} is building lab/manuals image.

on:
  push: 
    branches: [deploy]

jobs:
  build-oci:
    runs-on: [system]
    steps:

    - name: Check out repository code
      uses: https://git.lab/actions/checkout@v4
    
    - name: Checkout lab_services-config for rollout script
      run: |
        NOKNOWNHOSTS="-o UserKnownHostsFile=/dev/null" \
        NOHOSTCHECKS="-o StrictHostKeyChecking=no" \
        GIT_SSH_COMMAND="ssh $NOKNOWNHOSTS $NOHOSTCHECKS" \
        git clone --depth 1 git@git.lab:lab/lab_services-config.git \
          --branch deploy --single-branch lab_services-config

    - name: Dump environment variables
      run: env
    
    - name: Login to Gitea Docker Registry
      uses: https://git.lab/docker/login-action@v3
      with:
        registry: git.lab
        username: ${{ secrets.GITEADOCKER_USERNAME }}
        password: ${{ secrets.GITEADOCKER_TOKEN }}

    - name: Build system_manual image
      run: ./do cicd
    
    # Assumed that /opt/services is pre-created and owned by cicd.
    # Assumed that cicd has run docker login on destination machine.
    - name: Deploy system_manual image
      run: |
        ls && \
        ssh -p 2222 -o StrictHostKeyChecking=no cicd@www.lab \
          /bin/sh < lab_services-config/rollout.sh
```

In the above descriptor:

- We're triggered on `push` event to `deploy` branch.
- We checkout the relevant code into the working directory with the `uses: https://git.lab/actions/checkout` line. I suggest trying not to worry what the working directory actually is. Instead work relative to whatever it happens to be.
- Shallow clone `lab_service-config` repo to use its `rollout.sh` script. The above example ignores host key checking, which is not the best for security. If possible, its better to use `-o StrictHostKeyChecking=accept-new`.
- From the working directory, dump the environment variable for logging and troubleshooting purposes.
- Utilize the `docker/login-action` action to login to our Docker registry. Note: This is not the same as logging into our Docker registry in our _production server_ (as used in the final step). This only logs in for things running from the runner service, and is generally used so that we can `docker push` our final product.
- Run our `./do` script's `cicd` target. If you recall, this is equivalent to `./do build && ./do push` in a single command.
- Finally, we login to the _production server_ then pull and deploy the image via SSH on the production server. (Note: If there was more equity at stake, you'd want to add some unit testing between the build and the deployment.) We depend on our assumption that `lab_services-config` rollout.sh script automatically pulls updated images and starts them up.

## The Current Workflow

So now the workflow is:

- Clone or checkout the `main` branch of the system manual on a developer machine.
- Start the author container to see changes to the Markdown live with `./do start`.
- Make Markdown changes as desired.
- Commit & push changes to `main` branch and `origin`.
- Merge changes to local and upstream `deploy` branch via `./do deploy`.
- Wait ~5 minutes and verify changes are live. Optionally watch the progress via the project's Actions menu in Gitea.
- Rinse and Repeat as required.