#!/usr/bin/env bash

if [ -z "$BASH_VERSION" ]; then
  >&2 echo "This needs to run in bash"
  exit 1
fi

DATE=$(date "+%Y-%m-%d")

usage()
{
  echo "Usage: potman catalog [-hv]"
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

step "Initialize"
init_pottery_ssh

step "Read catalog from pottery"
IMAGES="$(echo "ls /usr/local/www/pottery" | \
  sftp -F "$SSHCONF_POTTERY" -q -b - "$POTTERY" | sed 's/ *$//g')"

OLD_IFS=$IFS
IFS=$'\n'
for line in $IMAGES; do
  line="$(echo "$line" | grep -E "\.xz$" || true)"
  if [ -n "$line" ]; then
    echo "$line" | sed "s/^\/usr\/local\/www\/pottery\///" | sed "s/\.xz$//"
  fi
done
IFS=$OLD_IFS

# if DEBUG is enabled, dump the variables
if [ $DEBUG -eq 1 ]; then
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
