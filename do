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

  #start)
  #  docker compose up -d
  #  ;;
  
  #stop)
  #  docker compose down
  #  ;;

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

  authorbuild)
    cd oci/author-site ; ./build.sh ; cd ${WD}
    ;;

  start)
    docker compose up -d
    ;;

  *)
    usage
    ;;
esac
