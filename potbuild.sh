#!/usr/bin/env bash

if [ -z "$BASH_VERSION" ]; then
  >&2 echo "This needs to run in bash"
  exit 1
fi
INCLUDE_DIR=$( dirname "${BASH_SOURCE[0]}" )

POTBUILDER=potbuilder
FLAVOURS_DIR=flavours
SSHCONF=${SSHCONF:-_build/.ssh_conf}
LOGFILE=_build/potbuild.log
FBSD=12.2
FBSD_TAG=12_2
DATE=$(date "+%Y-%m-%d")
STEPCOUNT=0

function usage()
{
  echo "Usage: $0 [-hv] [-d flavourdir] flavour"
}

OPTIND=1
while getopts "hvd:" _o ; do
  case "$_o" in
  d)
    FLAVOURS_DIR=$2
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

function run_ssh {
  if [ $DEBUG -eq 1 ]; then
    ssh -F $SSHCONF "$POTBUILDER" -- "$@" | tee -a $LOGFILE
    return ${PIPESTATUS[0]}
  else
    ssh -F $SSHCONF "$POTBUILDER" -- "$@" >> $LOGFILE
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

VERSION="${config_version}"
VERSION_SUFFIX="_$VERSION"

FLAVOUR_FILES="$FLAVOUR"

POT_CREATE_FLAVOURS="-f fbsd-update -f $FLAVOUR"
if [ "${config_runs_in_nomad}" == "true" ]; then
    FLAVOUR_FILES="$FLAVOUR_FILES $FLAVOUR+4"
    POT_CREATE_FLAVOURS="$POT_CREATE_FLAVOURS $FLAVOUR+4"
fi

FLAVOUR_FILES="$FLAVOUR_FILES $FLAVOUR.sh $FLAVOUR.d/distfile.tar"

for file in $FLAVOUR_FILES; do
  if [[ ! -f "$FLAVOURS_DIR"/$FLAVOUR/"$file" ]]; then
    >&2 echo "$FLAVOURS_DIR/$FLAVOUR/$file missing"
    exit 1
  fi
done

mkdir -p _build/tmp _build/artifacts

step "Initialize"
vagrant ssh-config $POTBUILDER > $SSHCONF


step "Test SSH connection"
run_ssh true

step "Remove existing remote $FLAVOUR.d"
run_ssh rm -rf /usr/local/etc/pot/flavours/$FLAVOUR.d

step "Copy flavour files"
tar -C "$FLAVOURS_DIR"/$FLAVOUR -cf - $FLAVOUR_FILES \
  | run_ssh tar -C /usr/local/etc/pot/flavours -xof -

step "Set remote flavour permissions"
run_ssh sudo chmod 775 /usr/local/etc/pot/flavours/$FLAVOUR.sh
run_ssh sudo chmod 775 /usr/local/etc/pot/flavours/$FLAVOUR.d

step "Destroy old pot images"
run_ssh "sudo pot destroy -F -p ${FLAVOUR}_\"$FBSD_TAG\" || true"

step "Build pot image"
run_ssh sudo RUNS_IN_NOMAD=${config_runs_in_nomad} \
  pot create -b "$FBSD" -p ${FLAVOUR}_"$FBSD_TAG" \
  -t single -N public-bridge $POT_CREATE_FLAVOURS -v

step "Snapshot pot image"
run_ssh sudo pot snapshot -p ${FLAVOUR}_"$FBSD_TAG"

step "Export pot"
run_ssh sudo pot export -l 0 -p ${FLAVOUR}_"$FBSD_TAG" \
  -t "$VERSION" -D /tmp

step "Copy pot image to local directory"
scp -qF "$SSHCONF" \
  "$POTBUILDER":/tmp/${FLAVOUR}_"$FBSD_TAG$VERSION_SUFFIX".xz \
  "$POTBUILDER":/tmp/${FLAVOUR}_"$FBSD_TAG$VERSION_SUFFIX".xz.skein \
  _build/tmp/.

step "Clean up build vm"
run_ssh sudo pot destroy -F -p ${FLAVOUR}_"$FBSD_TAG"
run_ssh sudo rm -f \
  /tmp/${FLAVOUR}_"$FBSD_TAG$VERSION_SUFFIX".xz \
  /tmp/${FLAVOUR}_"$FBSD_TAG$VERSION_SUFFIX".xz.skein

step "Move image into place"
mv \
  _build/tmp/${FLAVOUR}_"$FBSD_TAG$VERSION_SUFFIX".xz \
  _build/tmp/${FLAVOUR}_"$FBSD_TAG$VERSION_SUFFIX".xz.skein \
  _build/artifacts/.

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
