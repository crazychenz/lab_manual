---
sidebar_position: 2
title: Overview
---

:::danger Incomplete

This document is not yet written.

:::

## OS Install

- [Download Ubuntu 22.04.3](https://releases.ubuntu.com/22.04.3/ubuntu-22.04.3-desktop-amd64.iso).
- [Ubuntu LTS Releases](https://releases.ubuntu.com/)

- Create VM (mine is called lab.vinnie.work).

- Add extra hard disk to VM as "external storage".

- Start up VM with Ubuntu ISO to install operating system.

- Run through the various dialogs to setup the OS as desired.

  - **Caution**: When creating this documentation, I created a 4GB RAM VM. A fresh install of Ubuntu 22.04.3 Desktop (minimal install) crashed due to not enough memory. **Bah!** I haven't investigated this in depth yet, but it is _clearly_ a bug. To work around the issue (without doing a recovery repair), I explicitly added a 1.5GB swap partition in the disk partitioning section of the install. (Ideally the system would be able to use `/swapfile`, but in my case it failed to do so.) This is likely not an issue if you bump the memory up to 8GB before attempting an install of Ubuntu 22.04.3 Desktop.

- After the first boot, ensure that all packages are upgraded. This may or may not automatically popup as a dialog. In the terminal, you can always run something like the following:

  ```sh
  sudo su -c "apt-get update && apt-get upgrade"
  ```

- `apt-get install tmux` and add the following config `~/.tmux.conf`:

  ```sh
  set -g mouse on
  set -g default-terminal "screen-256color"
  set-option -g default-command bash

  set -g window-style 'fg=colour230,bg=colour235'
  set -g window-active-style 'fg=colour230,bg=colour233'

  set -g pane-active-border-style 'fg=colour237,bg=colour234'
  set -g pane-border-style 'fg=colour232,bg=colour234'
  set -g pane-border-format '###{pane_index} [ #{pane_tty} ] S:#{session_name} M:#{pane_marked} #{pane_width}x#{pane_height}'
  set -g pane-border-status 'bottom' # off|top|bottom

  bind-key x kill-pane
  ```

- `apt-get install openssh-server openssh-client`

- Setup LVM partitions. Note: I create a number of LVM partitions so that theoretically I have the flexibility to shrink and reclaim some low level partition table space if needed. This isn't a common situation in well funded production environments, but remains tactically prudent when working on a shoe string budget where you may not have the ability to purchase additional storage on a whim.

  ```sh
  sudo parted
  (parted) select /dev/sdb
  (parted) print
  (parted) mkpart primary 0% 25%
  (parted) mkpart primary 0% 25%
  (parted) mkpart primary 0% 25%
  (parted) mkpart primary 0% 25%
  (parted) set 1 lvm on
  (parted) set 2 lvm on
  (parted) set 3 lvm on
  (parted) set 4 lvm on
  ```

- Setup LVM configuration. For this, I used:

  - Standard Store (8GB) - for service state.
  - Secure Store (4G) - for security service state.
  - Manuals Store (4G) - for human readable documentation.
  - Artifact Store (32G) - for repository
  - _swing space_ (16G)

  ```
  sudo apt-get install lvm2
  sudo pvcreate /dev/sdb1
  sudo pvcreate /dev/sdb2
  sudo pvcreate /dev/sdb3
  sudo pvcreate /dev/sdb4
  sudo vgcreate external_vg /dev/sdb1 /dev/sdb2 /dev/sdb3 /dev/sdb4
  sudo lvcreate -n state_lv -L 8G external_vg
  sudo lvcreate -n secure_lv -L 4G external_vg
  sudo lvcreate -n manuals_lv -L 4G external_vg
  sudo lvcreate -n artifacts_lv -L 32G external_vg
  sudo mkfs.ext4 /dev/mapper/external_vg-state_lv
  sudo mkfs.ext4 /dev/mapper/external_vg-secure_lv
  sudo mkfs.ext4 /dev/mapper/external_vg-manuals_lv
  sudo mkfs.ext4 /dev/mapper/external_vg-artifacts_lv
  ```

  - Run the following and add the output as entries in `/etc/fstab`:

    ```
    pfx=/dev/mapper/external_vg-
    for p in state secure manuals artifacts
    do
      echo $(sudo blkid ${pfx}${p}_lv | cut -d ' ' -f2) /opt/${p} ext4
    done
    ```

  - LVM should now be setup.

- Install Text Editor: `apt-get install vim` (because Vim is the dominant terminal text editor)
- Install Docker

  - **Caution:** Do not install docker.io from Ubuntu repo and do not install docker-compose from PyPi. These are deprecated or out-of-date versions. See the [Docker Ubuntu Install Documentation](https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository) for more information.

  ```
  sudo apt-get update
  sudo apt-get install ca-certificates curl
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc

  # Add the repository to Apt sources:
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update
  sudo apt-get install docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin
  ```

- Add yourself (`whoami`) to docker group, logout and login.
  - Note: VSCode has an existing bug that prevents groups updates in Remote-SSH without restarting the server. User's have [reported this issue](https://github.com/microsoft/vscode-remote-release/issues/5813), but due to the aggresive ticket pruning employed by the upstream VSCode team, the issue has gone unresolved. As the comments elude to, you can restart the VSCode server with: `ps uxa | grep .vscode-server | awk '{print $2}' | xargs kill -9`. If that doesn't work, restarting the entire kernel (i.e the system) should work. IMHO, VSCode is overly aggresive with a number of cached areas and this is yet another.

- Setup user SSH keys: `ssh-keygen` (Accept defaults).

- Ensure git and python are installed: `sudo apt-get install git python3`

- Create a `bash-user-settings.sh` file in your home directory:

```sh
# Configure aliases fpr the terminal colors.
COLOR_LIGHT_BROWN="$(tput setaf 178)"
COLOR_LIGHT_PURPLE="$(tput setaf 135)"
COLOR_LIGHT_BLUE="$(tput setaf 87)"
COLOR_LIGHT_GREEN="$(tput setaf 78)"
COLOR_LIGHT_YELLOW="$(tput setaf 229)"
COLOR_YELLOW="$(tput setaf 184)"
COLOR_RESET="$(tput sgr0)"
COLOR_GREEN="$(tput setaf 83)"
COLOR_ORANGE="$(tput setaf 208)"
COLOR_RED="$(tput setaf 167)"
COLOR_GRAY="$(tput setaf 243)"

# Helper for showing colors in user specific terminal window+profile.
# Inspired by:
# https://www.lihaoyi.com/post/BuildyourownCommandLinewithANSIescapecodes.html
function show_colors {
    python3 <<PYTHON_SCRIPT
import sys
for i in range(0, 16):
    for j in range(0, 16):
        code = str(i * 16 + j)
        sys.stdout.write(u"\u001b[38;5;" + code + "m " + code.ljust(4))
    print("\u001b[0m")
PYTHON_SCRIPT
}

# Define colors for git branch/checkout depending on state.
# Inspired by:
# https://coderwall.com/p/pn8f0g
function git_branch {
  git rev-parse --is-inside-work-tree &> /dev/null
  if [ "$?" -eq "0" ]; then
    local git_status="$(git status 2> /dev/null)"
    local on_branch="On branch ([^${IFS}]*)"
    local on_commit="HEAD detached at ([^${IFS}]*)"

    if [[ ! $git_status =~ "working tree clean" ]]; then
        COLOR=$COLOR_RED
    elif [[ $git_status =~ "Your branch is ahead of" ]]; then
        COLOR=$COLOR_YELLOW
    elif [[ $git_status =~ "nothing to commit" ]]; then
        COLOR=$COLOR_LIGHT_GREEN
    else
        COLOR=$COLOR_ORANGE
    fi

    if [[ $git_status =~ $on_branch ]]; then
        local branch=${BASH_REMATCH[1]}
        echo -e "$COLOR($branch) "
    elif [[ $git_status =~ $on_commit ]]; then
        local commit=${BASH_REMATCH[1]}
        echo -e "$COLOR($commit) "
    fi
  fi
}
export -f git_branch

# Fetch the date in a canonical format.
function get_prompt_date {
    echo -e "$COLOR_GRAY$(date +%Y-%m-%d-%H:%M:%S)"
}
export -f get_prompt_date

# Get docker identity. Useful for doing `docker exec`, `docker stop`, etc.
# Note: This used to rely on /proc/1/cpuset, but with newer dockers we
#       now rely on volume mounting the output of --cidfile from `docker run`.
# Inspired by:
# https://stackoverflow.com/questions/20995351
function get_docker_ident {
    echo ""
}
export -f get_docker_ident

# Note: Without \[ \] properly placed, wrapping will not work correctly.
# More info found at: https://robotmoon.com/256-colors/
USERHOST_PSENTRY='\[$COLOR_LIGHT_BLUE\]\u\[$COLOR_GRAY\]@\[$COLOR_GREEN\]\h '
PS1="${debian_chroot:+($debian_chroot)}$USERHOST_PSENTRY"
PS1="$PS1\$(get_docker_ident)"
PS1="$PS1\$(git_branch)"
PS1="$PS1\$(get_prompt_date)"
WORKINGDIR='\[$COLOR_LIGHT_YELLOW\]\w'
PROMPT_DELIM='\[$COLOR_RESET\]\$ '
export PS1="$PS1\n$WORKINGDIR$PROMPT_DELIM"
```

- To activate the user settings file, you'll want to `source ~/bash-user-settings.sh`. To have the settings applied to all new terminals, run: `echo source ~/bash-user-settings.sh >> ~/.bashrc`.

- **OS Install Complete**