#!/usr/bin/env bash

if [ -z "$BASH_VERSION" ]; then
  >&2 echo "This needs to run in bash"
  exit 1
fi
INCLUDE_DIR=$( dirname "${BASH_SOURCE[0]}" )

FLAVOURS_DIR=""
DATE=$(date "+%Y-%m-%d")

POTTERY_PRUNE_AGE="+1h"
MINIPOT_PRUNE_CACHE_AGE="+1h"
MINIPOT_PRUNE_POT_AGE="+1h"

usage()
{
  echo "Usage: potman prune [-hv] [-d flavourdir] flavour"
}

OPTIND=1
while getopts "hvd:" _o ; do
  case "$_o" in
  d)
    FLAVOURS_DIR="${OPTARG}"
    ;;
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

if [ $# -ne 1 ]; then
  usage
  exit 1
fi

set -eE
trap 'echo error: $STEP failed' ERR
source "${INCLUDE_DIR}/common.sh"
common_init_vars

FLAVOUR=$1
if [[ ! "$FLAVOUR" =~ $FLAVOUR_REGEX ]]; then
  >&2 echo "Invalid flavour"
  exit 1
fi

step "Load potman config"
read_potman_config potman.ini
FREEBSD_VERSION="${config_freebsd_version}"
FBSD="${FREEBSD_VERSION}"
FBSD_TAG=${FREEBSD_VERSION//./_}

if [ -z "${FLAVOURS_DIR}" ]; then
  FLAVOURS_DIR="${config_flavours_dir}"
fi

step "Read flavour config"
read_flavour_config "${FLAVOURS_DIR}/${FLAVOUR}/${FLAVOUR}.ini"

VERSION="${config_version}"
VERSION_SUFFIX="_$VERSION"

step "Initialize"
init_pottery_ssh
init_minipot_ssh

step "Remove old files from pottery"
# shellcheck disable=SC2016
run_ssh_pottery "sudo find /usr/local/www/pottery \
  -name '${FLAVOUR}*.xz*' -mtime $POTTERY_PRUNE_AGE -delete"

step "Remove old files from pot cache"
# shellcheck disable=SC2016
run_ssh_minipot "sudo find /var/cache/pot -name '${FLAVOUR}*.xz*' \
  -mtime $MINIPOT_PRUNE_CACHE_AGE -delete"

step "Aggressively remove old pots"
run_ssh_minipot "for potname in \
  \$(pot list -q | grep ${FLAVOUR}_${FBSD_TAG}); do \
      (zfs get -H origin | awk '{ print \$3 }' | grep -q \
       -- \"/\$potname/\") || \
       find /opt/pot/jails/\$potname/conf -name fscomp.conf \
       -mtime $MINIPOT_PRUNE_POT_AGE \
       -exec sudo pot destroy -p \$potname \;
  done
"

step "Run pot prune on minipot"
run_ssh_minipot sudo pot prune

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
