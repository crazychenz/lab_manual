#!/bin/sh

docker run -ti --rm -w /opt/work -v $(pwd):/opt/work node:20-alpine npx $@
