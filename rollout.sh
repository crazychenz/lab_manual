#!/bin/sh
# This script is run from act_runner with the following cmd:
# ssh -p 2222 -o StrictHostKeyChecking=no cicd@www.lab /bin/sh < rollout.sh

cd /opt/services
if [ ! -e system_services ]; then
  GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" \
  git clone -b deploy git@git.lab:lab/system_services.git
fi
if [ ! -e system_services ]; then
  echo Failed to clone.
  exit 1
fi
cd system_services

# Update any service descriptor updates.
git pull

# Do the rollout.
docker compose pull && docker compose up -d

# Optional commands for cleaner maintenance.
# docker compose up --force-recreate --build -d
# docker image prune -f