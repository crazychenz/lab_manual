---
sidebar_position: 6
title: Gitea
draft: true
---

:::danger Incomplete

This document is not yet written.

:::

## Contents

- Preparing The System
- Installing Gitea Service (with docker compose)
- Create the admin organization (lab) and first repo (system_manual)
- Install and configure a Gitea Runner
- Mirror and install the checkout Action
- TODO: Initialize system_manual project and add an action workflow.
- TODO: Push a resulting image into gitea docker repository.

## System Adjustments

- Reconfigure SSHd to use a different port (e.g. 2222) in `/etc/ssh/sshd_config`.

  - `sudo systemctl restart sshd`

<!-- - Create initial gitea folder.

  - `sudo su -c "mkdir -p /opt/initial/gitea && chown -R $(id -u) /opt/initial"` -->

<!-- - **TODO:** Create a custom act_runner with caddy root certificate. This is accomplished, in Alpine, by appending the root certificate to `/etc/ssl/certs/ca-certificates.crt`. Copy cert to `/usr/local/share/ca-certificates` when using `update-ca-certificates` command. -->

<!-- - Create the initial `docker-compose.yml` file:

  ```yaml
  version: "3"

  networks:
    gitea:
      external: false

  services:
    gitea_svc:
      image: gitea/gitea:1.21.4
      container_name: gitea
      environment:
        - USER_UID=1000
        - USER_GID=1000
      restart: always
      networks:
        - gitea
      volumes:
        - ./data:/data
        - /etc/timezone:/etc/timezone:ro
        - /etc/localtime:/etc/localtime:ro
      ports:
        - "3000:3000"
        - "22:22"

    gitea_sys_runner:
      image: gitea/act_runner:latest-dind-rootless
      container_name: gitea_runner
      depends_on:
        - gitea_svc
      privileged: true
      environment:
        - CONFIG_FILE=/data/config.yaml
        - DOCKER_HOST=unix:///var/run/user/1000/docker.sock
      volumes:
        - /opt/initial/gitea/act_runner:/data
      restart: unless-stopped
  ``` -->

<!-- - Modify the USER_UID/USER_GID to match the gitea user values. -->

- `docker compose up -d gitea_svc`

- Open Gitea via its hostname (`https://git.lab/`) from `dnsmasq_svc` in a browser on the same network. 

- Leave the defaults and click "Install Gitea" button- toward the bottom of the page.

- On the next screen (i.e. the login screen), click "Need an account? Register Now."

  - Select a username (e.g. gitea_user) and a password > 8 characters (e.g. password), then click "Register Account".

  - Note: If you forget the password, you can reset it with:

    ```
    docker exec -it <container-id> su git bash -c "gitea admin user change-password -u <user> -p <pw>"
    ```

- We now have an operating git revision control with many usability features found in other git frontends like Gitlab, Github, Gogs, and many others.

- From here we want to add our SSH key to our account in Gitea. Grab the key in the clipboard: `cat /home/user/.ssh/id_rsa.pub` and paste it as an SSH key in Gitea under the account settings.

- **Git and Artifact Repository is installed.**

## Create Organization, Create Manual Repo, Setup System Runner

- Create a new organization called `lab`, visibility as `Private`, click "Create Organization".

- Create `system_manual` repository under `lab` organization via the web interface, visibility `Private`. Accept defaults and click "Create Repository".

- You should now have some commands as an example for using the new repo. We'll simply clone this into the `/opt/manuals` folder as `/opt/manuals/system_manual`:

  ```sh
  git clone git@git.lab:lab/system_manual.git
  ```

- Create docusaurus project (with `node:20-alpine` docker container).

  ```sh
  docker run -ti --rm \
    -u $(id -u) -w /opt/work -v $(pwd):/opt/work \
    node:20-alpine npx create-docusaurus@latest docusaurus classic
  ```

- Once it completes, commit/push to git to ensure you have a clean baseline. (From here on out, we'll assume that you know how to properly git commit/push with the exception of some general hints for when to commit/push as a suggestion.)

## Create act_runner configuration

**Caution:** Do not mix `var=val` and `var: val` conventions in the `environment:` section of any `docker-compose.yml` file. See [Github Issue 11267](https://github.com/docker/compose/issues/11267) for more information.

```
# Create a state folder for our runner
sudo chown user /opt/state
mkdir -p /opt/state/gitea_sys_runner/data
# Generate a clean act_runner configuration
docker compose run --entrypoint "act_runner" gitea_sys_runner generate-config \
  > /opt/state/gitea_sys_runner/data/config.yaml
# Fetch registration token
docker compose exec -u 1000 gitea_svc \
  gitea --config /data/gitea/conf/app.ini actions generate-runner-token
```

```
# Register runner with gitea
docker compose run \
  --entrypoint "act_runner" -w /data -u 1000 gitea_sys_runner \
  register --no-interactive \
    --instance https://git.lab \
    --token 5Q7uvFgpZFOFKmzFGVgFh8X4dtwKj0qzcKJNcRg6 \
    --name sys_runner \
    --labels system,another
# Restart with compose to ensure auto start persistence
docker compose down gitea_sys_runner && docker compose up -d gitea_sys_runner
# Check Gitea runners for success
```

**Note:** Gitea documentation fails to mention that its autostart run.sh script assumes everything is run from data. This means that when we explicitly register the runner, it must be with the working directory `/data` as well. If not, the `.runner` state will be stored in `/.runner` and not saved into the host.

## Add Checkout Action

Create `actions` org, create `actions/checkout` repo, run the following commands:

```
git clone --mirror https://github.com/actions/checkout.git checkout
cd checkout
git remote rm origin
git remote add origin git@git.lab:actions/checkout.git
git push --mirror origin
```

## Setup Project Actions

- To enable actions for a repository, open the project in the Gitea Web GUI. 
- Go to the project Settings (roughly under the Fork button in the upper right).
- Under the "Advanced Settings" section, check the "Actions" checkbox.
- Click "Update Settings" at the bottom of the section.
- If successful, you'll now see an "Action" link in the top bar of the project between "Pull Requests" and "Packages".
- Click "Actions" to see past and/or present Action workflows and logs.

Once we setup a project to execute a workflow on an event, you can come to this page to see, in the browser, the action terminal output as its running.


Here is an example Gitea Action that you can put in `.gitea/workflows/deploy.yml` of a project folder.

**===================================================================**
**TODO:** !!Document the process to setup actions for a project!!
**===================================================================**

```yaml
name: Gitea Actions Demo
run-name: ${{ gitea.actor }} is testing out Gitea Actions 🚀
on:
  push:
    branches:
      - main
    #schedule:
    ## * is a special character in YAML so you have to quote this string
    #- cron:  '30 5,17 * * *'

jobs:
  asdf:
    #name: asdf
    #needs: [other_job]
    #defaults:
    #  run:
    #    shell: bash
    #    working-directory: ./scripts
    # Run unconditionally (i.e. run even if other_job fails)
    #if: ${{ always() }}
    runs-on: ubuntu-latest
    steps:
      - run: echo "🎉 The job was automatically triggered by a ${{ gitea.event_name }} event."
      - run: echo "🐧 This job is now running on a ${{ runner.os }} server hosted by Gitea!"
      - run: echo "🔎 The name of your branch is ${{ gitea.ref }} and your repository is ${{ gitea.repository }}."
      - name: Check out repository code
        uses: actions/checkout@v3
      - run: echo "💡 The ${{ gitea.repository }} repository has been cloned to the runner."
      - run: echo "🖥️ The workflow is now ready to test your code on the runner."
      - name: List files in the repository
        run: |
          ls ${{ gitea.workspace }}
        #timeout-minutes: 10
      - run: echo "🍏 This job's status is ${{ job.status }}."
```

When we push to `deploy` branch, the action is triggered. The action should be one of:

- A docker command to build something.
- An SSH command to run something remotely.`

Note: Since GitOps controls the configuration above the baseline system, it is accepted that some repositories will contain credentials or keys required for system automation. These configuration specific repositories are kept separate from the source code repositories.

```
name: proxy.vinnie.work
run-name: ${{ gitea.actor }} is deploying configs to proxy.vinnie.work.

on:
  push:
    branches: ['deploy']

jobs:
  build-oci:
    runs-on: [linux,cicd]
    steps:

    - name: Dump environment variables.
      run: env

    - name: Running webhook-rollout.sh @ proxy.vinnie.work
      run: |
        ssh -o StrictHostKeyChecking=no \
          -i /home/cicd/.ssh/id_rsa cicd@proxy.vinnie.work \
          /opt/proxy.vinnie.work-config/scripts/webhook-rollout.sh

    - name: Running webhook-rollout.sh @ k3s.vinnie.work
      run: |
        ssh -o StrictHostKeyChecking=no \
          -i /home/cicd/.ssh/id_rsa cicd@k3s.vinnie.work \
          /opt/k3s.vinnie.work-config/scripts/webhook-rollout.sh
```

_docusaurus_

- Create public `actions` organization

- Create public/visible `checkout` repository in `actions` organization.

- Copy the github actions/checkout into our `checkout` repo. Optionally tag it appropriately (e.g. v4).

- _Setup manuals repo with workflow definition and other conventions._

- Enable Actions in manual repo settings. Click update settings.