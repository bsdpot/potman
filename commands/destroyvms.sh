#!/usr/bin/env bash

if [ -z "$BASH_VERSION" ]; then
  >&2 echo "This needs to run in bash"
  exit 1
fi

usage()
{
  echo "Usage: potman destroyvms [-hv] [-m machine]"
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

step "Destroy vagrant vms"
vagrant destroy -f "${MACHINES[@]}"

step "Success"
