---
sidebar_position: 30
title: Gitea Runner for CICD
draft: false
---

## Overview

In the previous article, we ran through a developer workflow for developing, testing, and deploying our documentation system. In this article, we'll integrate a low cost method to employ Continuous Integration and Continuous Deployment (CICD). Our primary goal is to be in a position where we only concern ourselves with the development and testing of a configuration or product. Once we `git push` changes (to a specific branch) upstream, the system should automatically build (i.e continuous integration) the upstream updates and deploy the build output to the relevant production instance (i.e continuous deployment).

## Create act_runner configuration

The way that Gitea implements CICD is through `act_runner`s. This is a binary that polls Gitea for updates. When relevant updates are identified, the environment that is running `act_runner` will be tasked with executing a number of commands specified in the repository itself. Before any of this happens, we need to setup and register the `act_runner` with the Gitea service.

For our GODS environment, we're going to start with a dockerized `act_runner` that we'll setup to build and deploy our lab manual. The container we'll start with has been baselined by the Gitea developers and is itself based on Alpine Linux. Therefore, we need to ensure that all of the things we need to build and deploy our site is included and configured in a way that works with Alpine Linux (v3.18 at the time of this writing).

The runner we're going to create will be called the `gitea_sys_runner`. The service descriptor for the master `docker-compose.yml` is:

```yaml
gitea_sys_runner:
  image: git.lab/lab/act_runner:latest
  depends_on: [dnsmasq_svc, caddy_svc, gitea_svc]
  build:
    context: context
    dockerfile_inline: |
      FROM gitea/act_runner:latest-dind-rootless
      USER root
      RUN apk add -U nodejs
      RUN wget --no-check-certificate https://tls.lab/certs/root.crt \
        -O /etc/ssl/certs/lab-root.crt \
        && wget --no-check-certificate https://tls.lab/certs/intermediate.crt \
        -O /etc/ssl/certs/lab-intermediate.crt \
        && cat /etc/ssl/certs/lab-root.crt /etc/ssl/certs/ca-certificates.crt \
        && cat /etc/ssl/certs/lab-intermediate.crt >> /etc/ssl/certs/ca-certificates.crt
      USER rootless
  container_name: gitea_sys_runner
  # Required for docker-in-docker control.
  privileged: true
  environment:
    - CONFIG_FILE=/data/config.yaml
    - DOCKER_HOST=unix:///var/run/user/1000/docker.sock
  volumes:
    - /opt/state/gitea_sys_runner/data:/data
  restart: unless-stopped
```

**Caution:** Do not mix `var=val` and `var: val` conventions in the `environment:` section of any `docker-compose.yml` file. See [Github Issue 11267](https://github.com/docker/compose/issues/11267) for more information.

Once the docker-compose.yml is updated, run the following commands to get an API key required to register `gitea_sys_runner` with our Gitea service.

```sh
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

In the following commands, we'll do the actual registration from the command line. If you look at the arguments, the `--name` argument is the name of the service that you'll see in Gitea. The `--labels` argument provides a set of labels that we can later use to filter out the kinds of runners that are compatible with different git repos and products.

Once we have the API key (e.g. `5Q7uvFgpZFOFKmzFGVgFh8X4dtwKj0qzcKJNcRg6`), we want register the service from the command line by running:

```sh
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

Verify that the running has successfully registered with Gitea from inside the Gitea administration section. Click the `Actions` menu link in the left side bar and then `Runners` in the sub-menu. You should be able to see the runner `sys_runner` with its status as `Idle` as well as some other information.

### Adding External Actions

Because the Gitea actions are mostly compatible with GitHub action, there are a wealth of actions that can be imported for our use. 

**action/checkout**

One of the most important features required for our runner is the ability to checkout the referenced code from the repository. This checkout capability has been pre-implemented by GitHub and we'll reuse it by adding it to our Gitea instance.

In summary, in Gitea, create an `actions` organization, and then create an `actions/checkout` repo, then run the following commands in a temporary folder:

```
git clone --mirror https://github.com/actions/checkout.git checkout
cd checkout
git remote rm origin
git remote add origin git@git.lab:actions/checkout.git
git push --mirror origin
```

**docker/login-action**

Since I often need a runner to login to the Docker registry, the `docker/login-action` allows me to do just that while using a username and password passed in via Gitea Runner secrets. Note: When adding secrets, I recommend doing it at the organization level so that the same credentials are shared across projects.

Create a `docker` organization (if not already created) and then an empty `login-action` repository within the organization, then run the following:

```
git clone --mirror https://github.com/docker/login-action.git login-action
cd login-action
git remote rm origin
git remote add origin git@git.lab:docker/login-action.git
git push --mirror origin
```

**docker/build-push-action**

Another common action for container creation is for a runner to build then push. We actually do this as well, but instead of using the upstream action we opt to use our build system so that its more repeatable when we want to do it outside of the runner's environment.

Create a `docker` organization (if not already created) and then an empty `build-push-action` repository within the organization, then run the following:

```
git clone --mirror https://github.com/docker/build-push-action.git build-push-action
cd build-push-action
git remote rm origin
git remote add origin git@git.lab:docker/build-push-action.git
git push --mirror origin
```

### Setup Pre-Project Actions Feature

Finally, for each project that you want to use the Gitea runners with, you'll need to enable `Actions` as a feature.

- To enable actions for a repository, open the project in the Gitea Web GUI. 
- Go to the project Settings (roughly under the Fork button in the upper right).
- Under the "Advanced Settings" section, check the "Actions" checkbox.
- Click "Update Settings" at the bottom of the section.
- If successful, you'll now see an "Action" link in the top bar of the project between "Pull Requests" and "Packages".
- Click "Actions" to see past and/or present Action workflows and logs.

Once we setup a project to execute a workflow on an event, you can come to this Action page to see, in the browser, the action terminal output as its running.

### Example Project Action (Runner) Configuration

Here is an example Gitea Action that you can put in the file path `.gitea/workflows/deploy.yml` of a project folder.

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

## Up Next

Assuming everything went to plan, you should now have a working runner waiting for work to do. In the next article, we'll finally set up our documentation to automatically build and deploy when we `'push` updates to its `deploy` branch.







