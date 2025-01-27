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
  cat <<-"EOF"
	Usage: potman publish [-hv] [-d flavourdir] [-V version] flavour

	Options:
	    -d   Directory containing flavours
	    -h   Help
	    -v   Verbose

	flavour is the flavour to publish. If it contains slashes,
	it will be taken as the direct path to a flavour (regardless
	of what is in the d parameter).
	EOF
}

VERSION=

OPTIND=1
while getopts "hvd:V:" _o ; do
  case "$_o" in
  d)
    FLAVOURS_DIR="${OPTARG}"
    ;;
  h)
    usage
    exit 0
    ;;
  V)
    VERSION="${OPTARG}"
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
if [[ "${FLAVOUR}" == */* ]]; then
  FLAVOURS_DIR="$(dirname "${FLAVOUR}")"
  FLAVOUR="$(basename "${FLAVOUR}")"
fi
if [[ ! "$FLAVOUR" =~ $FLAVOUR_REGEX ]]; then
  >&2 echo "Invalid flavour"
  exit 1
fi

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

if [ -z "$VERSION" ]; then
  VERSION="${config_version}"
fi
validate_version "$VERSION"
VERSION_SUFFIX="_$VERSION"

step "Initialize"
init_pottery_ssh

artifact_basename="${FLAVOUR}_${FBSD_TAG}${VERSION_SUFFIX}"

step "Check if remote tmp has enough disk space available"
diskneed=$(stat -f "%z" \
  "_build/artifacts/$artifact_basename.xz")
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
signature_cmds=
if [ -f _build/artifacts/"$artifact_basename".xz.skein.sig ]; then
  signature_cmds="\
    mput \"$artifact_basename\".xz.skein.sig
    rename \"$artifact_basename\".xz.skein.sig \
      ../pottery/\"$artifact_basename\".xz.skein.sig
  "
fi

sftp -F "$SSHCONF_POTTERY" -q -b - "$POTTERY" >/dev/null<<EOF
lcd _build/artifacts
cd /usr/local/www/pottery.tmp
mput "$artifact_basename".xz
mput "$artifact_basename".xz.meta
mput "$artifact_basename".xz.skein
$signature_cmds
rename "$artifact_basename".xz.skein \
  ../pottery/"$artifact_basename".xz.skein
rename "$artifact_basename".xz.meta \
  ../pottery/"$artifact_basename".xz.meta
rename "$artifact_basename".xz \
  ../pottery/"$artifact_basename".xz
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
