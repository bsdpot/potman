#!/usr/bin/env bash

if [ -z "$BASH_VERSION" ]; then
  >&2 echo "This needs to run in bash"
  exit 1
fi

usage()
{
  echo "Usage: potman stopvms [-hv] [-m machine]"
}

MACHINES=()

OPTIND=1
while getopts "hvm:" _o ; do
  case "$_o" in
  h)
    usage
    exit 0
    ;;
  m)
    MACHINES=( "${OPTARG}" )
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

mkdir -p _build

step "Check tooling"
ansible --version >/dev/null
git --version >/dev/null
vagrant --version >/dev/null
vboxheadless --version >/dev/null

step "Make sure vagrant plugins are installed"
(vagrant plugin list | grep "vagrant-disksize" >/dev/null)\
  || vagrant plugin install vagrant-disksize

step "Stop vagrant vms"
vagrant halt "${MACHINES[@]}"

step "Success"
