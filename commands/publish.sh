#!/usr/bin/env bash

if [ -z "$BASH_VERSION" ]; then
  >&2 echo "This needs to run in bash"
  exit 1
fi
INCLUDE_DIR=$( dirname "${BASH_SOURCE[0]}" )

FLAVOURS_DIR=""
DATE=$(date "+%Y-%m-%d")

usage()
{
  echo "Usage: potman publish [-hv] [-d flavourdir] flavour"
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
source "${INCLUDE_DIR}/common.sh"
common_init_vars

step "Load common source"
source "${INCLUDE_DIR}/common.sh"

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

step "Check if remote tmp has enough disk space available"
diskneed=$(stat -f "%z" \
  "_build/artifacts/${FLAVOUR}_${FBSD_TAG}${VERSION_SUFFIX}.xz")
((diskneed *= 2))
diskfree=$(echo "df /usr/local/www/pottery" \
  | sftp -F "$SSHCONF_POTTERY" -q -b - "$POTTERY" \
  | grep -v "Avail" \
  | tail -n1 \
  | awk '{ print $3 }')
((diskfree *= 1024))

if [[ "$diskneed" -gt "$diskfree" ]]; then
  >&2 echo "Not enough diskspace available ($diskneed > $diskfree)"
  false
fi

step "Copy files to remote tmp"
sftp -F "$SSHCONF_POTTERY" -q -b - "$POTTERY" >/dev/null<<EOF
lcd _build/artifacts
cd /usr/local/www/pottery
mput ${FLAVOUR}_"$FBSD_TAG$VERSION_SUFFIX".xz
mput ${FLAVOUR}_"$FBSD_TAG$VERSION_SUFFIX".xz.meta
mput ${FLAVOUR}_"$FBSD_TAG$VERSION_SUFFIX".xz.skein
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
