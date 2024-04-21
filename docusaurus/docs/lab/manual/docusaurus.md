---
sidebar_position: 20
title: Initializing Docusaurus
draft: false
---

In the following document we'll be creating and publishing our first bit of documentation. It is recommended that you do this on a different machine or VM from the one hosting your DNS/CA/HTTPS/GIT services. When we're doing development, we don't usually do it on the production server and our GODS environment should not be any different. Personally, I use a development only VM for this kind of thing (in contrast to a _production_ `lab` vm where I host the above mentioned services).

## Getting Started

To create our initial Docusaurus project, we'll want an upstream Git repo, Docker, and an internet connection. Then we'll create a `npx.sh` script that will do all of the work within a Docker container. You can optionally install node and run it on you platform. I prefer to keep the host system clean by running as much as reasonable in the container.

### Creating Upstream Git Repo

Since we're planning ahead and thinking bigger than just ourselves, lets ensure that all of our more _stable_ projects (i.e. lab manuals) are not owned by our username, but as part of an organization (managed by Gitea).

Login to Gitea and create a new organization called `lab`, (optionally) set visibility as `Private`, click "Create Organization". Once created, go to the organization's repository listing (e.g. `https://git.lab/lab`). From this page, click the green "New Repository" button. Name the respository something like `system_manual` via the web interface, (optionally) set visibility `Private`. You can accept defaults for the rest of the options and click "Create Repository".

You should now have some commands as an example for using the new repo. We'll simply clone this into the `/opt/manuals` folder as `/opt/manuals/system_manual`:

  ```sh
  git clone git@git.lab:lab/system_manual.git
  cd system_manual
  git checkout -b main
  ```

### Initialize (Contained) Docusaurus

Create the following script in `/opt/manuals/system_manual`:

`npx.sh`:

```sh
#!/bin/sh

docker run -ti --rm -w /opt/work -v $(pwd):/opt/work node:20-alpine npx $@
```

Make it executable: `chmod +x /opt/manuals/system_manual/npx.sh`

This script will use the current working directory as its output. I recommend running it within `/opt/manuals/system_manual`. Once you are in the directory where you want the `docusaurus` folder to appear, run the following:

```sh
./npx.sh create-docusaurus@latest docusaurus classic
```

If everything completed successfully, change to the `docusaurus` sub-folder. Within, you should find a number of files and folders you can setup for your needs. See [Docusaurus Documentation](https://docusaurus.io/docs) for more detailed information.

For the sake of this topic, I'll mention that all documentation we'll be managing with markdown should go into the `docs` folder. When you first create a project, there are some example files in there. You can chose to keep those around or trash them. Within the `docs` folder, I'm currently tracking this manual in a `lab` subfolder (i.e. `./docusaurus/docs/lab`).

This `lab` folder is where we'll keep all documentation on how to setup and operate our lab environment.

At this point I would recommend that you snapshot our first and sane state for the system manual project and push it upstream:

```sh
git add .
git commit -m "Initial commit of Docusaurus for the System Manual"
git push origin main
```

Note: Blindly adding everything with `git add .` is ok here because the Docusaurus project comes with its own .gitignore for ignoring folders like `node_modules`.

## Creating Build Scripts

Now that we have a docusaurus project created, I prefer to setup some build files to properly test and develop documentation within a contained environment. If you installed nodejs on your host system, you could do `npm run start` to get started right away. Since I prefer to keep things contained, there is a bit of one-time overhead to deal with first.

As a personal convention, in the `/opt/manuals/system_manual` folder, create an `oci` (i.e. Open Container Initiative) folder for our static site container build description.

```sh
mkdir -p oci/{static,author}-site
```

Notice that there is a `static-site` build and an `author-site` build being created. The static-site is our production build when we're ready to deploy to the masses. The author-site build is what we're be running while we're typing up the documentation and we want an immediate preview of what we've written.

The author's build script (`oci/author-site/build.sh`):

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

Create the author docker image's Dockerfile `oci/author-site/Dockerfile`:

```Dockerfile
FROM node:20-alpine

WORKDIR /opt/workspace

# First copy only package-lock.json and package.json so we can keep
# node_modules in its own cache layer based on the package files.
RUN mkdir docusaurus
COPY ./docusaurus/package*.json ./docusaurus/
RUN cd docusaurus && npm install

# Copy the rest of the source code to do the product build.
COPY . .
WORKDIR /opt/workspace/docusaurus

CMD ["npm", "run", "start"] 
```

Create the publisher docker image's build script `oci/static-site/build.sh`:

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

Create the publisher docker image's push script `oci/static-site/push.sh`:

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

# First copy only package-lock.json and package.json so we can keep
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

Create a `docker-compose.yml` (in the `/opt/manuals/system_manual` folder) for _authoring_:

```yaml
# compose v2

services:
  author:
    image: git.lab/lab/manuals:author
    volumes:
    - ./docusaurus/docs:/opt/workspace/docusaurus/docs
    network_mode: host
```

Due to personal convention, I prefer to have a `do` script (in the `system_manual` folder) that'll simplify invoking the various common actions used in the maintenance of the containers, images, and their execution. Note: Always run the `do` script from the directory it lives in.

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
- `./do push` - Push the static site image to your upstream docker repository.
- `./do cicd` - Same as `./do build && ./do push`

**Note:** Now would be a good time to `git commit/push` all of your new changes.

## Build it!

Phew!, now that we have all of the conventional files setup for our project we can start to use them to demonstrate a workflow.

The build a developer/author workflow, we run:

```sh
./do authorbuild
```

If the `authorbuild` build target finished without error, we can now start up the service:

```sh
./do start
```

If everything executed as expected, you should now have docusaurus service running on the system running the container on port `3000`. If your IP is `192.168.1.10`, you should be able to see the documentation at `http://192.168.1.10:3000`. 

Now, if you make modifications to the markdown in the `./docusaurus/docs` folder, the browser should automatically update within a second or two. This is a great way to view exactly what users will see when we eventually publish to `https://www.lab` (or any other location intended for end users).

Presuming you are happy with what has been developed/written in the author instance of the documentation, we now want to build the static version for publication/deployment. (Before building, `git commit` changes!) 

To do build the static site image, run:

```sh
./do build && ./do push
```

If everything went to plan, you can run the static site locally by running something like:

```sh
docker run --rm -p 8080:80 git.lab/lab/manuals:latest
```

Now access the site on a browser (presuming your IP is 192.168.1.10) with `http://192.168.1.10:8080`. You should see the same site as your authorbuild, but now its completely contained within the container. This container can be run as-is from any host. In our case, we want to run it from our `www.lab` machine on localhost so that the Caddy service we've already installed can point to it.

On the `www.lab` machine (or the machine that Caddy is pointing to for `www.lab`), do something like the following:

```sh
docker pull git.lab/lab/manuals:latest
docker run -d --restart always -p 127.0.0.1:1280:80 git.lab/lab/manuals:latest
```

The `https://www.lab` link should now be working and hosting the documentation site.

## Recap

1. We initialized a Docusaurus project for our lab manual documentation.
2. We created build scripts for building an author docker image and a static docker image.
3. We built the author image and started writing documentation.
4. Once we completed updates and reviewed them in the author build, we built a static-site docker image and pushed it to Gitea.
5. We pulled the docker image from Gitea onto our production server and started it up in a way that our HTTPS Caddy service could access it.

Going forward, we want to improve on this build process by utilizing continuous integration and continuous delivery. In other words, we want to be in a position where we only concern ourselves with the authoring of the documentation. Once we `git push` changes to our documentation, the static site should automatically build (i.e continuous integration) and push updates to Gitea. After Gitea is updated, the production instance should automatically be updated in the production server (i.e continuous deployment).
