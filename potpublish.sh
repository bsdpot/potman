#!/usr/bin/env bash

if [ -z "$BASH_VERSION" ]; then
  >&2 echo "This needs to run in bash"
  exit 1
fi

POTTERY=pottery
FLAVOURS_DIR=flavours
SSHCONF=${SSHCONF:-_build/.ssh_conf}
LOGFILE=_build/potpublish.log
FBSD=12.2
FBSD_TAG=12_2
DATE=$(date "+%Y-%m-%d")
STEPCOUNT=0

usage()
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

function step {
  ((STEPCOUNT+=1))
  STEP="$@"
  echo "$STEP" >> $LOGFILE
  [ $VERBOSE -eq 0 ] || echo "$STEPCOUNT. $STEP"
}

step "Initialize"
vagrant ssh-config > $SSHCONF

VERSION=$(head -n 1 "$FLAVOURS_DIR"/$FLAVOUR/$FLAVOUR.d/CHANGELOG.md)
VERSION_SUFFIX="_$VERSION"

step "Copy files to remote tmp"
sftp -F $SSHCONF -q -b - "$POTTERY" >/dev/null<<EOF
lcd _build/artifacts
cd /usr/local/www/pottery
mput "$FLAVOUR"_"$FBSD_TAG$VERSION_SUFFIX".xz
mput "$FLAVOUR"_"$FBSD_TAG$VERSION_SUFFIX".xz.skein
exit
EOF

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
