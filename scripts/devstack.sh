#!/bin/bash

current_dir="$(dirname "$0")"
sultan="$(dirname "$current_dir")"/sultan

# shellcheck source=scripts/messaging.sh
source "$current_dir/messaging.sh"


help_text="${NORMAL}An Open edX Remote Devstack Toolkit by Appsembler

${BOLD}${GREEN}devstack${NORMAL}
  Manages the devstack on your remote machine.

  ${BOLD}USAGE:${NORMAL}
    sultan devstack <command> [argement]

  ${BOLD}COMMANDS:${NORMAL}
    up        Runs devstack servers.
    stop      Stops and unmounts devstack server(s).
    make      Performs a devstack make command on the GCP instance.
    unmount   Releases the devstack mount from your machine.
    mount     Mounts devstack files from your GCP instance onto your
              local machine.

  ${BOLD}EXAMPLES:${NORMAL}
    sultan devstack up
    sultan devstack stop
    sultan devstack make lms-logs
"


make() {
  #############################################################################
  # Performs a devstack make command on the GCP instance.                     #
  #############################################################################
  ssh -tt devstack "
    cd $DEVSTACK_DIR &&
    source $VIRTUAL_ENV/bin/activate &&
    make DEVSTACK_WORKSPACE=$DEVSTACK_WORKSPACE OPENEDX_RELEASE=$OPENEDX_RELEASE VIRTUAL_ENV=$VIRTUAL_ENV $1"
}

up()  {
  #############################################################################
  # Runs devstack servers.                                                    #
  #############################################################################
  make down
	make pull
	make "$DEVSTACK_RUN_COMMAND" &&
  ## Copy JSON config file before starting & Restart LMS in hopes the changes got picked up.
  ssh -tt devstack "
    docker cp ~/workspace/edx-env/lms.env.json edx.devstack.lms:/edx/app/edxapp/lms.env.json"
  make lms-static
	success "The devstack is up and running and should be running the Gymnasium theme."
}

unmount() {
  #############################################################################
  # Releases the devstack mount from your machine.                            #
  #############################################################################
  if [ "$(uname -s)" == Darwin ]; then
    UNMOUNT=diskutil
  else
    UNMOUNT=sudo
  fi

	("$UNMOUNT" unmount force "$MOUNT_DIR" && \
		rm -rf "$MOUNT_DIR" && \
		success "Workspace unmounted successfully.") \
	|| warn "No mount found" "SKIPPING"
}

stop()  {
  #############################################################################
  # Stops and unmounts devstack server.                                       #
  #############################################################################
  unmount
  make stop
	success "Your devstack stopped successfully."
}

down() {
  #############################################################################
  # Clone of stop.                                                            #
  #############################################################################
  stop
}

mount() {
  #############################################################################
  # Mounts devstack files from your GCP instance onto your local machine.     #
  #############################################################################
  IP_ADDRESS=$(eval "$sultan" instance ip)

	mkdir -p "$MOUNT_DIR"
	message "Mount directory created." "$MOUNT_DIR"
	sshfs \
	  -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,allow_other,defer_permissions,IdentityFile="$SSH_KEY" \
	  "$USER_NAME@$IP_ADDRESS:$DEVSTACK_WORKSPACE" "$MOUNT_DIR"
	success "Workspace has been mounted successfully."
}

help() {
  # shellcheck disable=SC2059
  printf "$help_text"
}

# Print help message if command is not found
if ! type -t "$1" | grep -i function > /dev/null; then
  help
  exit 1
fi

"$@"
