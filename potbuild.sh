#!/usr/bin/env bash

if [ -z "$BASH_VERSION" ]; then
  >&2 echo "This needs to run in bash"
  exit 1
fi

POTBUILDER=potbuilder
SSHCONF=${SSHCONF:-_build/.ssh_conf}
LOGFILE=_build/potbuild.log
FLAVOUR="myflavour"
FBSD=12.2
FBSD_TAG=12_2
DATE=$(date "+%Y-%m-%d")
STEPCOUNT=0

set -eE
trap 'echo error: $STEP failed' ERR 

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

mkdir -p _build

step "Initialize"
vagrant ssh-config > $SSHCONF

VERSION=$(head -n 1 "$FLAVOUR"/"$FLAVOUR".d/CHANGELOG.md)
VERSION_SUFFIX="_$VERSION"

step "Test SSH connection"
run_ssh true

step "Remove existing remote $FLAVOUR.d"
run_ssh rm -rf /usr/local/etc/pot/flavours/"$FLAVOUR".d

step "Copy flavour files"
tar -cf - "$FLAVOUR"/"$FLAVOUR" "$FLAVOUR"/"$FLAVOUR"+4 \
  "$FLAVOUR"/"$FLAVOUR".sh "$FLAVOUR"/"$FLAVOUR".d/CHANGELOG.md \
  "$FLAVOUR"/"$FLAVOUR".d/myfile.tar \
  | run_ssh tar -C /usr/local/etc/pot/flavours \
    --strip-components 1 -xof -

step "Set remote flavour permissions"
run_ssh sudo chmod 775 /usr/local/etc/pot/flavours/"$FLAVOUR".sh
run_ssh sudo chmod 775 /usr/local/etc/pot/flavours/"$FLAVOUR".d

step "Destroy old pot images"
run_ssh "sudo pot destroy -F -p \"$FLAVOUR\"_\"$FBSD_TAG\" || true"

step "Build pot image"
run_ssh sudo pot create -b "$FBSD" -p "$FLAVOUR"_"$FBSD_TAG" \
  -t single -N public-bridge -f fbsd-update -f "$FLAVOUR" -f "$FLAVOUR"+4 -v

step "Snapshot pot image"
run_ssh sudo pot snapshot -p "$FLAVOUR"_"$FBSD_TAG"

step "Export pot"
run_ssh sudo pot export -l 0 -p "$FLAVOUR"_"$FBSD_TAG" \
  -t "$VERSION" -D /tmp

step "Make local output directory"
mkdir -p "_build/$DATE"/"$FLAVOUR"

step "Copy pot image to local directory"
scp -qF "$SSHCONF" \
  "$POTBUILDER":/tmp/"$FLAVOUR"_"$FBSD_TAG$VERSION_SUFFIX".xz \
  "_build/$DATE"/"$FLAVOUR"/.

step "Copy pot image skein to local directory"
scp -qF "$SSHCONF" \
  "$POTBUILDER":/tmp/"$FLAVOUR"_"$FBSD_TAG$VERSION_SUFFIX".xz.skein \
  "_build/$DATE"/"$FLAVOUR"/.

step "Clean up build vm"
run_ssh sudo pot destroy -F -p "$FLAVOUR"_"$FBSD_TAG"
run_ssh sudo rm -f /tmp/"$FLAVOUR"_"$FBSD_TAG$VERSION_SUFFIX".xz \
  rm -f /tmp/"$FLAVOUR"_"$FBSD_TAG$VERSION_SUFFIX".xz.skein

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
