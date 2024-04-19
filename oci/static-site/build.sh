#!/bin/sh

#if [ ! -e "context/build.tar" ]; then
#  echo "No build context found. Did you run `yarn build`?"
#  exit 1
#fi

epoch=1707651051
version=0.$(printf "%x" $(($(date +%s)-${epoch})))
image_prefix=git.lab/lab/system_manual
src_relpath=../..

docker build -f Dockerfile -t ${image_prefix}:stage ${src_relpath} && \
  echo -n "${version}" > .build-version && \
  echo -n "${image_prefix}" > .build-image-prefix