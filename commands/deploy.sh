#!/usr/bin/env bash

if [ -z "$BASH_VERSION" ]; then
  >&2 echo "This needs to run in bash"
  exit 1
fi
INCLUDE_DIR=$( dirname "${BASH_SOURCE[0]}" )

DISK_MINFREE_MB=4096
FLAVOURS_DIR=""
DATE=$(date "+%Y-%m-%d")

usage()
{
  cat <<-"EOF"
	Usage: potman deploy [-hqv] [-d flavourdir] [-s suffix]
	                     [-V version] flavour

	Options:
	    -d   Directory containing flavours
	    -s   Suffix used in nomad job (allows to run multiple deployments
	         in parallel)
	    -h   Help
	    -q   Quick (do not execute special scripts)
	    -V   Override image version
	    -v   Verbose

	flavour is the flavour to deploy. If it contains slashes,
	it will be taken as the direct path to a flavour (regardless
	of what is in the d parameter).
	EOF
}

QUICK="NO"
VERSION=

OPTIND=1
while getopts "hqvd:s:V:" _o ; do
  case "$_o" in
  d)
    FLAVOURS_DIR="${OPTARG}"
    ;;
  h)
    usage
    exit 0
    ;;
  q)
    QUICK="YES"
    ;;
  s)
    SUFFIX="${OPTARG}"
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

PUBLIC_SUFFIX=""
if [[ -n "$SUFFIX" ]]; then
  if [[ ! "$SUFFIX" =~ ^[a-zA-Z][a-zA-Z0-9]{1,9}$ ]]; then
    >&2 echo "Invalid suffix"
    exit 1
  fi
  PUBLIC_SUFFIX="-${SUFFIX}"
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
NETWORK="${config_network}"

if [ "${config_runs_in_nomad}" != "true" ]; then
  >&2 echo "Pot is not supposed to run in nomad"
  false
fi

if [ -z "$VERSION" ]; then
  VERSION="${config_version}"
fi
validate_version "$VERSION"
VERSION_SUFFIX="_$VERSION"

step "Initialize"
init_minipot_ssh

step "Test SSH connection"
run_ssh_minipot true

step "Check if minipot has approx. enough diskspace available"
diskfree=$(ssh -F "$SSHCONF_MINIPOT" "$MINIPOT" -- df -m / | \
  tail -n1 | awk '{ print $4 }')

if [[ "$DISK_MINFREE_MB" -gt "$diskfree" ]]; then
  >&2 echo "Not enough diskspace available ($DISK_MINFREE_MB > $diskfree)"
  false
fi

if [ -e "${FLAVOURS_DIR}/${FLAVOUR}/config_consul.sh" ] &&
    [ "$QUICK" != "YES" ]; then
  step "Load consul configuration"
  env SSHCONF="$SSHCONF_MINIPOT" SUFFIX="$SUFFIX" "${FLAVOURS_DIR}/${FLAVOUR}/config_consul.sh"
fi

step "Load job into minipot nomad"
<"${FLAVOURS_DIR}/${FLAVOUR}/${FLAVOUR}.d/minipot.job" \
  sed "s/%%pottery%%/http:\/\/$NETWORK.2/g" |
  sed "s/%%freebsd_tag%%/$FBSD_TAG/g" |\
  sed "s/%%pot_version%%/$VERSION/g" |\
  sed "s/%%suffix%%/$SUFFIX/g" |\
  sed "s/%%public_suffix%%/$PUBLIC_SUFFIX/g" |\
  run_ssh_minipot nomad run -

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
