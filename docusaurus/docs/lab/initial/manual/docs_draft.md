---
sidebar_position: 3
title: Docs
draft: true
---


:::danger Incomplete

This document is not yet written.

:::

`npx.sh`:

```sh
#!/bin/sh

docker run -ti --rm -w /opt/work -v $(pwd):/opt/work node:20-alpine npx $@
```

```sh
mkdir -p manuals/oci/static-site
cd manuals
./npx.sh create-docusaurus@latest docusaurus classic
```

`oci/static-site/build.sh`:

```sh
#!/bin/sh

#if [ ! -e "context/build.tar" ]; then
#  echo "No build context found. Did you run `yarn build`?"
#  exit 1
#fi

epoch=<EPOCH>
version=0.$(printf "%x" $(($(date +%s)-${epoch})))
image_prefix=git.lab/lab/manuals
src_relpath=../..

docker build -f Dockerfile -t ${image_prefix}:stage ${src_relpath} && \
  echo -n "${version}" > .build-version && \
  echo -n "${image_prefix}" > .build-image-prefix
```

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

`do`:

```sh
#!/bin/sh

usage() {
  echo "Possible Targets:"
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

  build)
    # Note: I would prefer to use `--strip-components=1` with ADD, but
    # that option does not exist. Therefore we strip when building the tar.
    #yarn build && tar -cf oci/static-site/context/build.tar -C build .
    cd oci/static-site && ./build.sh && cd ${WD}
    ;;

  push)
    cd oci/static-site && ./push.sh && cd ${WD}
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