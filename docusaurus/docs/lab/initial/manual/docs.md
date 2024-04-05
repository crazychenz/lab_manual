---
sidebar_position: 20
title: Initializing Docusaurus
draft: false
---

:::danger Incomplete

This document is not yet written.

:::

## Getting Started

To create our initial Docusaurus project, we'll need Docker and an internet connection. Then we'll create a `npx.sh` script that will do all of the work within a Docker container. You can optionally install node and run it on you platform. I prefer to keep the host system clean by running as much as reasonable in the container.

`npx.sh`:

```sh
#!/bin/sh

docker run -ti --rm -w /opt/work -v $(pwd):/opt/work node:20-alpine npx $@
```

This script will use the current working directory as its output. I recommend running it within `/opt/manuals/system_manual`. Once you are in the directory where you want the `docusaurus` folder to appear, run the following:

```sh
./npx.sh create-docusaurus@latest docusaurus classic
```

If everything completed successfully, change to the `docusaurus` folder. Within, you should find a number of files and folders you can setup for your needs. See [Docusaurus Documentation](https://docusaurus.io/docs) for more detailed information.

For the sake of this topic, I'll mention that all documentation we'll be managing with markdown should go into the `docs` folder. When you first create a project, there are some example files in there. You can chose to keep those around or trash them. Within the `docs` folder, I'm currently tracking this manual in a `lab` subfolder (i.e. `./docusaurus/docs/lab`).

This `lab` folder is where we'll keep all documentation on how to setup and operate our lab environment.

At this point I would recommend that you change your folder to `/opt/manuals/system_manual` and run the  following to snapshot our first and sane state for the system manual project:

```sh
git init
git add .
git commit -m "Initial commit of Docusaurus for the System Manual"
```

## Creating Build Scripts

Now that we have a docusaurus project created, we need to setup some build files to properly test and develop documentation within its environment. If you installed nodejs on your host system, you could do `npm run start` to get started right away. Since I prefer to keep things contained, there is a bit of one-time overhead to deal with first.

As a personal convention, create an `oci` (i.e. Open Container Initiative) folder for our static site container build description.

```sh
mkdir -p oci/{static,author}-site
```

Create the author's build script `oci/author-site/build.sh`.

```sh
#!/bin/sh

epoch=1707600000
version=0.$(printf "%x" $(($(date +%s)-${epoch})))
image_prefix=git.lab/lab/manuals
src_relpath=../..

docker build -f Dockerfile -t ${image_prefix}:author ${src_relpath} && \
  echo -n "${version}" > .build-version && \
  echo -n "${image_prefix}" > .build-image-prefix
```

Create the author's Dockerfile `oci/author-site/Dockerfile`:

```Dockerfile
FROM node:20-alpine

WORKDIR /opt/workspace

# Frist copy only package-lock.json and package.json so we can keep
# node_modules in its own cache layer based on the package files.
RUN mkdir docusaurus
COPY ./docusaurus/package*.json ./docusaurus/
RUN cd docusaurus && npm install

# Copy the rest of the source code to do the product build.
COPY . .
WORKDIR /opt/workspace/docusaurus

CMD ["npm", "run", "start"] 
```

Create the publisher's build script `oci/static-site/build.sh`:

```sh
#!/bin/sh

epoch=1707600000
version=0.$(printf "%x" $(($(date +%s)-${epoch})))
image_prefix=git.lab/lab/manuals
src_relpath=../..

docker build -f Dockerfile -t ${image_prefix}:stage ${src_relpath} && \
  echo -n "${version}" > .build-version && \
  echo -n "${image_prefix}" > .build-image-prefix
```

Create the publisher's push script `oci/static-site/build.sh`:

```sh
#!/bin/sh

version=$(cat .build-version)
image_prefix=$(cat .build-image-prefix)

docker tag ${image_prefix}:stage ${image_prefix}:${version} \
  && docker push ${image_prefix}:${version} \
  && docker tag ${image_prefix}:${version} ${image_prefix}:latest \
  && docker push ${image_prefix}:latest \
  && echo "Tagged and published ${image_prefix}:${version} as latest"
```

Create the `Dockerfile` for the static site.

`oci/static-site/Dockerfile`:

```Dockerfile
FROM node:20-alpine as builder

WORKDIR /opt/workspace

# Frist copy only package-lock.json and package.json so we can keep
# node_modules in its own cache layer based on the package files.
RUN mkdir docusaurus
COPY ./docusaurus/package*.json ./docusaurus/
RUN cd docusaurus && npm install

# Copy the rest of the source code to do the product build.
COPY . .
RUN cd docusaurus && npm run build

FROM caddy:alpine
COPY --from=builder /opt/workspace/caddy/Caddyfile /etc/caddy/Caddyfile
COPY --from=builder /opt/workspace/docusaurus/build /srv
```

Create a `docker-compose.yml` (in the `/opt/manuals/system_manual` folder) for authoring:

```yaml
# compose v2

services:
  author:
    image: git.lab/lab/manuals:author
    volumes:
    - ./docusaurus/docs:/opt/workspace/docusaurus/docs
    network_mode: host
```

Due to personal convention, create a `do` script (in the `system_manual` folder) that'll simplify invoking the various common actions used in the maintenance of the containers, images, and their execution. Note: Always run the `do` script from the directory it lives in.

`do`:

```sh
#!/bin/sh

usage() {
  echo "Possible Targets:"
  echo "- authorbuild - docker build"
  echo "- build - docker build"
  echo "- push - docker push"
  echo "- start - docker compose up"
  echo "- stop - docker compose down"
  echo "- restart - stop & start"
  echo "- cicd - build & push"
  echo "- deploy - git checkout/merge/push in deploy"
  exit 1
}

if [ $# -lt 1 ]; then
  usage
fi

DO_CMD=$1
WD=$(pwd)

case $DO_CMD in

  authorbuild)
    cd oci/author-site ; ./build.sh ; cd ${WD}
    ;;

  start)
    docker compose up -d
    ;;

  stop)
    docker compose down
    ;;

  restart)
    ./do stop ; ./do start
    ;;

  build)
    # Note: I would prefer to use `--strip-components=1` with ADD, but
    # that option does not exist. Therefore we strip when building the tar.
    #yarn build && tar -cf oci/static-site/context/build.tar -C build .
    cd oci/static-site && ./build.sh && cd ${WD}
    ;;

  push)
    cd oci/static-site && ./push.sh && cd ${WD}
    ;;

  cicd)
    ./do build && ./do push
    ;;

  deploy)
    # Guard against dirty repos.
    git status 2>/dev/null | grep "nothing to commit" || exit 1
    git checkout deploy
    git merge main
    git push origin deploy
    git checkout main
    ;;

  *)
    usage
    ;;
esac

```

Make the `do` script executable: `chmod +x do`

## The `do` Script

The `do` script is a convention that I use to simplify a number of actions. 

To get started with our new build system, simply run `./do authorbuild` once and then whenever you want to write and preview documentation on the fly (no rebuilding), run `./do start`. It'll start a server on `localhost:3000` that can be port forwarded to where ever you have a browser. (Or `Ctrl` + `Shift` + `V` in VSCode to see a preview if you don't want to use Docusaurus).

In general, some of these targets are used by me (the human), others are more often used by automated processes (the machine).

### For Human Use

- `./do authorbuild` - Build the image required to modify and view documentation on the fly.
- `./do start` - Start the author version of the site.
- `./do stop` - Stop the author version of the site.
- `./do restart` - Same as `./do start && ./do stop`
- `./do deploy` - Merge and push changes into deploy branch.

### For Machine Use (and manual testing)

- `./do build` - Build the image required to host the static site.
- `./do push` - Publish the static site image to.
- `./do cicd` - Same as `./do build && ./do push`




