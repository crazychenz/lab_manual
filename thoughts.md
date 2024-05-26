push vi DOCKER_HOST
- require ssh access from runner
- require docker access/creds?

push min files then docker compose up
- require ssh access from runner
- require docker access from host
- Can use watchtower

pull git repo then docker compose up
- require ssh access from runner
- require docker access from host
- require git access from host
- Can be polled to check for updates

pull via watchtower
- require docker access from host
- polls for updates every 60 seconds
- doesn't consider interrupting existing ops


NOIT WORKING
```
REGISTRY="my.registry.com:5000"
REPOSITORY="awesome-project-of-awesomeness"


LATEST="`wget -qO- http://$REGISTRY/v1/repositories/$REPOSITORY/tags`"
LATEST=`echo $LATEST | sed "s/{//g" | sed "s/}//g" | sed "s/\"//g" | cut -d ' ' -f2`

RUNNING=`docker inspect "$REGISTRY/$REPOSITORY" | grep Id | sed "s/\"//g" | sed "s/,//g" |  tr -s ' ' | cut -d ' ' -f3`

if [ "$RUNNING" == "$LATEST" ];then
    echo "same, do nothing"
else
    echo "update!"
    echo "$RUNNING != $LATEST"
fi
```

BUILD: build capability and push image

DEPLOY:
push files (compose, rollout, tests) then rollout (docker compose up)
- requires ssh access from runner
- requires docker access from host

TEST:
Periodically (on deployment and then 5-10 mins) run tests



CD with push and pray delivery
- low lift
- high risk of interrupted ops
- high risk of missed state changes

CI push separate from CD push
- medium lift
- push for CI build
- push for CD deploy (could be system)

CD into larger system (k8s)
- more moving parts, more to mess up
- difficult to address from external proxy


## Flux Template

Install Debian
- LVM, all in one drive, no swap
Login with root
- Install sudo and git
- `adduser cicd sudo`
- echo "cicd ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/cicd
- logout

Login with cicd

```
git clone https://github.com/crazychenz/lab_essential
cd lab_essential/collector
sudo ./install-docker.sh
sudo adduser cicd docker
```

Logout, login

Pull devcontainer image (~1.5GiB)
`docker pull ghcr.io/onedr0p/cluster-template/devcontainer:latest`

devcontainer missing openssl