#!/bin/sh

version=$(cat .build-version)
image_prefix=$(cat .build-image-prefix)

docker tag ${image_prefix}:stage ${image_prefix}:${version} \
  && docker push ${image_prefix}:${version} \
  && docker tag ${image_prefix}:${version} ${image_prefix}:latest \
  && docker push ${image_prefix}:latest \
  && echo "Tagged and published ${image_prefix}:${version} as latest"