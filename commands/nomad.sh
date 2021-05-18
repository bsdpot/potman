#!/usr/bin/env bash

if [ -z "$BASH_VERSION" ]; then
  >&2 echo "This needs to run in bash"
  exit 1
fi

DATE=$(date "+%Y-%m-%d")

usage()
{
  echo "Usage: potman nomad ..."
}

set -eE
trap 'echo error: $STEP failed' ERR
source "${INCLUDE_DIR}/common.sh"
common_init_vars

step "Load potman config"
read_potman_config potman.ini
FREEBSD_VERSION="${config_freebsd_version}"
FBSD="${FREEBSD_VERSION}"
FBSD_TAG=${FREEBSD_VERSION//./_}

step "Check nomad cluster status"
init_minipot_ssh
ssh -F "$SSHCONF_MINIPOT" "$MINIPOT" -- nomad "$@"

# if DEBUG is enabled, dump the variables
if [ "$DEBUG" -eq 1 ]; then
    printf "\n\n"
    echo "Dump of variables"
    echo "================="
    echo "FBSD: $FBSD"
    echo "FBSD_TAG: $FBSD_TAG"
    echo "Version: $VERSION with suffix: $VERSION_SUFFIX"
    printf "\n\n"
    echo "Date: $DATE"
    printf "\n\n"
fi

step "Success"
