#!/usr/bin/env bash

if [ -z "$BASH_VERSION" ]; then
  >&2 echo "This needs to run in bash"
  exit 1
fi

DATE=$(date "+%Y-%m-%d")

usage()
{
  echo "Usage: potman status [-hv]"
}

OPTIND=1
while getopts "hv" _o ; do
  case "$_o" in
  h)
    usage
    exit 0
    ;;
  v)
    VERBOSE="YES"
    ;;
  *)
    usage
    exit 1
    ;;
  esac
done

shift "$((OPTIND-1))"

if [ $# -ne 0 ]; then
  usage
  exit 1
fi

set -eE
trap 'echo error: $STEP failed' ERR
source "${INCLUDE_DIR}/common.sh"
common_init_vars

step "Load potman config"
read_potman_config potman.ini
FREEBSD_VERSION="${config_freebsd_version}"
FBSD="${FREEBSD_VERSION}"
FBSD_TAG=${FREEBSD_VERSION//./_}

step "Check tooling"
ansible --version >/dev/null
git --version >/dev/null
vagrant --version >/dev/null
vboxheadless --version >/dev/null

step "Make sure vagrant plugins are installed"
(vagrant plugin list | grep "vagrant-disksize" >/dev/null)\
  || vagrant plugin install vagrant-disksize

step "Show vagrant status"
echo "
===> Vagrant status <==="
vagrant status | grep -E "($MINIPOT|$POTBUILDER|$POTTERY)"

step "Check nomad cluster status"
echo "
===> Nomad status <==="
init_minipot_ssh
ssh -F "$SSHCONF_MINIPOT" "$MINIPOT" -- nomad status

step "Check consul status"
echo "
===> Consul status <==="
echo "> Datacenters:"
ssh -F "$SSHCONF_MINIPOT" "$MINIPOT" -- consul catalog datacenters
echo "> Nodes:"
ssh -F "$SSHCONF_MINIPOT" "$MINIPOT" -- consul catalog nodes
echo "> Services:"
ssh -F "$SSHCONF_MINIPOT" "$MINIPOT" -- consul catalog services

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
