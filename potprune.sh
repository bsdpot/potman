#!/usr/bin/env bash

if [ -z "$BASH_VERSION" ]; then
  >&2 echo "This needs to run in bash"
  exit 1
fi
INCLUDE_DIR=$( dirname "${BASH_SOURCE[0]}" )

MINIPOT=minipot
POTTERY=pottery
FLAVOURS_DIR=flavours
SSHCONF=${SSHCONF:-_build/.ssh_conf}
LOGFILE=_build/potprune.log
FBSD=12.2
FBSD_TAG=12_2
DATE=$(date "+%Y-%m-%d")
STEPCOUNT=0

POTTERY_PRUNE_AGE="+1h"
MINIPOT_PRUNE_CACHE_AGE="+1h"
MINIPOT_PRUNE_POT_AGE="+1h"

usage()
{
  echo "Usage: $0 [-hv] [-d flavourdir] flavour"
}

OPTIND=1
while getopts "hvd:" _o ; do
  case "$_o" in
  d)
    FLAVOURS_DIR=${OPTARG}
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

FLAVOUR=$1

if [[ -z "$FLAVOUR" ]]; then
  usage
  exit 1
fi

if [[ ! "$FLAVOUR" =~ ^[a-zA-Z][a-zA-Z0-9]{1,15}$ ]]; then
  >&2 echo "Invalid flavour"
  exit 1
fi

case "$VERBOSE" in
  [Yy][Ee][Ss]|1)
    VERBOSE=1
  ;;
  *)
    VERBOSE=0
  ;;
esac

case "$DEBUG" in
  [Yy][Ee][Ss]|1)
    DEBUG=1
  ;;
  *)
    DEBUG=0
  ;;
esac

function run_ssh_minipot {
  if [ $DEBUG -eq 1 ]; then
    ssh -F "$SSHCONF" "$MINIPOT" -- "$@" | tee -a $LOGFILE
    return "${PIPESTATUS[0]}"
  else
    ssh -F "$SSHCONF" "$MINIPOT" -- "$@" >> $LOGFILE
  fi
}

function run_ssh_pottery {
  if [ $DEBUG -eq 1 ]; then
    ssh -F "$SSHCONF" "$POTTERY" -- "$@" | tee -a $LOGFILE
    return "${PIPESTATUS[0]}"
  else
    ssh -F "$SSHCONF" "$POTTERY" -- "$@" >> $LOGFILE
  fi
}


function step {
  ((STEPCOUNT+=1))
  STEP="$*"
  echo "$STEP" >> $LOGFILE
  [ $VERBOSE -eq 0 ] || echo "$STEPCOUNT. $STEP"
}

set -eE
trap 'echo error: $STEP failed' ERR

step "Load common source"
source "${INCLUDE_DIR}/common.sh"

step "Read config"
read_flavour_config "${FLAVOURS_DIR}/${FLAVOUR}/${FLAVOUR}.ini"

VERSION="${config_version}"
VERSION_SUFFIX="_$VERSION"

step "Initialize"
vagrant ssh-config "$MINIPOT" "$POTTERY" > "$SSHCONF"

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
