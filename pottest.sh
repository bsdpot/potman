#!/usr/bin/env bash

if [ -z "$BASH_VERSION" ]; then
  >&2 echo "This needs to run in bash"
  exit 1
fi
INCLUDE_DIR=$( dirname "${BASH_SOURCE[0]}" )

MINIPOT=minipot
DISK_MINFREE_MB=4096
FLAVOURS_DIR=flavours
SSHCONF=${SSHCONF:-_build/.ssh_conf}
LOGFILE=_build/pottest.log
FBSD=12.2
FBSD_TAG=12_2
DATE=$(date "+%Y-%m-%d")
STEPCOUNT=0

usage()
{
  echo "Usage: $0 [-hv] [-d flavourdir] [-s suffix] flavour"
}

OPTIND=1
while getopts "hvd:s:" _o ; do
  case "$_o" in
  d)
    FLAVOURS_DIR=${OPTARG}
    ;;
  h)
    usage
    exit 0
    ;;
  s)
    SUFFIX=${OPTARG}
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

PUBLIC_SUFFIX=""
if [[ -n "$SUFFIX" ]]; then
  if [[ ! "$SUFFIX" =~ ^[a-zA-Z][a-zA-Z0-9]{1,8}$ ]]; then
    >&2 echo "Invalid suffix"
    exit 1
  fi
  PUBLIC_SUFFIX="-${SUFFIX}"
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

function run_ssh {
  if [ $DEBUG -eq 1 ]; then
    ssh -F $SSHCONF "$MINIPOT" -- "$@" | tee -a $LOGFILE
    return ${PIPESTATUS[0]}
  else
    ssh -F $SSHCONF "$MINIPOT" -- "$@" >> $LOGFILE
  fi
}

function step {
  ((STEPCOUNT+=1))
  STEP="$@"
  echo "$STEP" >> $LOGFILE
  [ $VERBOSE -eq 0 ] || echo "$STEPCOUNT. $STEP"
}

set -eE
trap 'echo error: $STEP failed' ERR

step "Load common source"
source "${INCLUDE_DIR}"/common.sh

step "Read config"
read_flavour_config "$FLAVOURS_DIR"/$FLAVOUR/$FLAVOUR.ini

if [ "${config_runs_in_nomad}" != "true" ]; then
  >&2 echo "Pot is not supposed to run in nomad"
  false
fi

VERSION="${config_version}"
VERSION_SUFFIX="_$VERSION"

step "Initialize"
vagrant ssh-config $MINIPOT > $SSHCONF

step "Check if minipot has approx. enough diskspace available"
diskfree=$(ssh -F $SSHCONF "$MINIPOT" -- df -m / | \
  tail -n1 | awk '{ print $4 }')

if [[ "$DISK_MINFREE_MB" -gt "$diskfree" ]]; then
  >&2 echo "Not enough diskspace available ($DISK_MINFREE_MB > $diskfree)"
  false
fi

if [ -e "$FLAVOURS_DIR"/$FLAVOUR/config_consul.sh ]; then
  step "Load consul configuration"
  env SSHCONF=$SSHCONF SUFFIX=$SUFFIX "$FLAVOURS_DIR"/$FLAVOUR/config_consul.sh
fi

step "Load job into minipot nomad"
cat "$FLAVOURS_DIR"/$FLAVOUR/$FLAVOUR.d/minipot.job |\
  sed "s/%%freebsd_tag%%/$FBSD_TAG/g" |\
  sed "s/%%pot_version%%/$VERSION/g" |\
  sed "s/%%suffix%%/$SUFFIX/g" |\
  sed "s/%%public_suffix%%/$PUBLIC_SUFFIX/g" |\
  run_ssh nomad run -

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
