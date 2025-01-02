#!/usr/bin/env bash

set -e

VERSION_REGEX='^[0-9](\.[0-9a-zA-Z_-]+)*$'
ORIGIN_REGEX='^([a-zA-Z0-9_]*)$'
KILN_NAME_REGEX='^[a-zA-Z]([0-9a-zA-Z]+)*$'
FREEBSD_VERSION_REGEX='^(13\.[34]|14\.[12])$'
# poor
NETWORK_REGEX='^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$'
# shellcheck disable=SC2034
FLAVOUR_REGEX='^[a-zA-Z][a-zA-Z0-9-]{0,19}[a-zA-Z0-9]$'

MINIPOT=minipot
POTBUILDER=potbuilder
POTTERY=pottery

function common_init_vars() {
  STEPCOUNT=0
  STEP=
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
}

function step() {
  ((STEPCOUNT+=1))
  STEP="$*"
  if [ -n "$LOGFILE" ]; then
    echo "$STEP" >> "$LOGFILE"
  fi
  [ $VERBOSE -eq 0 ] || echo "$STEPCOUNT. $STEP"
}

# Hacky, needs to be replaced
# shellcheck disable=SC2206 disable=SC2086 disable=SC2116
function read_ini_file() {
  OLD_IFS=$IFS
  ini="$(<$1)"                # read the file
  ini="${ini//[/\\[}"          # escape [
  ini="${ini//]/\\]}"          # escape ]
  IFS=$'\n' && ini=( ${ini} ) # convert to line-array
  ini=( ${ini[*]//;*/} )      # remove comments with ;
  ini=( ${ini[*]//#*/} )      # remove comments with #
  ini=( ${ini[*]/\	=/=} )  # remove tabs before =
  ini=( ${ini[*]/=\	/=} )   # remove tabs be =
  ini=( ${ini[*]/\ =\ /=} )   # remove anything with a space around =
  ini=( ${ini[*]/#\\[/\}$'\n'cfg_section_} ) # set section prefix
  ini=( ${ini[*]/%\\]/ \(} )    # convert text2function (1)
  ini=( ${ini[*]/=/=\( } )    # convert item to array
  ini=( ${ini[*]/%/ \)} )     # close array parenthesis
  ini=( ${ini[*]/%\\ \)/ \\} ) # the multiline trick
  ini=( ${ini[*]/%\( \)/\(\) \{} ) # convert text2function (2)
  ini=( ${ini[*]/%\} \)/\}} ) # remove extra parenthesis
  ini[0]="" # remove first element
  ini[${#ini[*]} + 1]='}'    # add the last brace

  for i in ${!ini[*]}; do
    if [[ ${ini[$i]} =~ ^([^=]+)=(.*$) ]]; then
      ini[$i]="config_${BASH_REMATCH[1]}=${BASH_REMATCH[2]}"
    fi
  done
  eval "$(echo "${ini[*]}")" # eval the result
  IFS=$OLD_IFS
}

# shellcheck disable=SC2154
function read_potman_config() {
  read_ini_file "$1"
  cfg_section_kiln

  if [[ ! "${config_name}" =~ $KILN_NAME_REGEX ]]; then
      >&2 echo "invalid name in $1"
      exit 1
  fi

  if [[ "${config_vm_manager}" != "vagrant" ]]; then
      >&2 echo "invalid vm_manager in $1"
      exit 1
  fi

  if [[ ! "${config_freebsd_version}" =~ $FREEBSD_VERSION_REGEX ]]; then
    >&2 echo "unsupported freebsd version in $1"
    exit 1
  fi

  if [[ ! "${config_network}" =~ $NETWORK_REGEX ]]; then
    >&2 echo "invalid network in $1"
    exit 1
  fi

  if [[ "${config_flavours_dir}" = "" ]]; then
    config_flavours_dir="flavours"
  fi
}

function validate_version() {
  if [[ ! "$1" =~ $VERSION_REGEX ]]; then
      >&2 echo "invalid version passed"
      exit 1
  fi
}

# shellcheck disable=SC2154
function read_flavour_config() {
  read_ini_file "$1"
  cfg_section_manifest

  if [ "$config_runs_in_nomad" != "true" ] &&
      [ "$config_runs_in_nomad" != "false" ]; then
    >&2 echo "invalid runs_in_nomad in manifest"
    exit 1
  fi

  if [[ ! "${config_version}" =~ $VERSION_REGEX ]]; then
      >&2 echo "invalid version in manifest"
      exit 1
  fi

  if [[ ! "${config_origin}" =~ $ORIGIN_REGEX ]]; then
      >&2 echo "invalid origin in manifest"
      exit 1
  fi

  if [ -z "$config_keep" ]; then
      config_keep=false
  fi

  if [ "$config_keep" != "true" ] &&
      [ "$config_keep" != "false" ]; then
    >&2 echo "invalid keep in manifest"
    exit 1
  fi
}

function main_usage() {
  echo "
Usage: $0 command

Commands:
    build       -- Build a flavour
    catalog     -- See catalog contents
    consul      -- Run consul in minipot
    deploy      -- Test deploy image
    destroyvms  -- Destroy VMs
    help        -- Show usage
    init        -- Initialize new kiln
    nomad       -- Run nomad in minipot
    packbox     -- Create vm box image
    prune       -- Reclaim disk space
    publish     -- Publish image to pottery
    startvms    -- Start (and provision) VMs
    status      -- Show status
    stopvms     -- Stop VMs
"
}

function exec_potman() {
  CMD=$1
  shift
  exec \
    env INCLUDE_DIR="$(dirname "${BASH_SOURCE[0]}")" \
    env LOGFILE="${LOGFILE}" \
    "${INCLUDE_DIR}/${CMD}.sh" "$@"
}

# only makes sense on FreeBSD, noop on other platforms
function exit_if_vmm_loaded() {
  if command -v "kldstat" >/dev/null 2>&1; then
    if kldstat -qm vmm; then
      >&2 echo "Please unload kernel module vmm, it breaks virtualbox"
      exit 1
    fi
  fi
}

function main() {
  set -e

  if [ $# -lt 1 ]; then
    main_usage
    exit 1
  fi

  CMD="$1"
  shift


  if [ "${CMD}" = "help" ]; then
    CMD="$1"
    if [ -z "$CMD" ]; then
      main_usage
      exit 0
    fi
    ARGS=("-h")
  else
    ARGS=("$@")
  fi

  if [ "${CMD}" = "init" ]; then
    LOGFILE=""
  else
    if [ ! -f potman.ini ]; then
      >&2 echo "Not inside a kiln (no potman.ini found). Try 'potman init'."
      exit 1
    fi

    read_potman_config potman.ini

    if [ "${PWD##*/}" != "${config_name}" ]; then
      >&2 echo "Kiln name doesn't match directory name"
      exit 1
    fi
    LOGFILE="${PWD}/_build/$CMD.log"
  fi

  case "${CMD}" in
    build|catalog|consul|deploy|destroyvms|init|nomad|packbox|\
    prune|publish|startvms|status|stopvms)
       exec_potman "${CMD}" "${ARGS[@]}"
      ;;
    *)
      main_usage
      exit 1
      ;;
  esac
}

function init_minipot_ssh() {
  SSHCONF_MINIPOT="_build/.ssh_conf.$MINIPOT"
  vagrant ssh-config "$MINIPOT" > "$SSHCONF_MINIPOT"
}

function init_potbuilder_ssh() {
  SSHCONF_POTBUILDER="_build/.ssh_conf.$POTBUILDER"
  vagrant ssh-config "$POTBUILDER" > "$SSHCONF_POTBUILDER"
}

function init_pottery_ssh() {
  SSHCONF_POTTERY="_build/.ssh_conf.$POTTERY"
  vagrant ssh-config "$POTTERY" > "$SSHCONF_POTTERY"
}

function run_ssh_minipot {
  if [ $DEBUG -eq 1 ]; then
    ssh -F "$SSHCONF_MINIPOT" "$MINIPOT" -- "$@" | tee -a "$LOGFILE"
    return "${PIPESTATUS[0]}"
  else
    ssh -F "$SSHCONF_MINIPOT" "$MINIPOT" -- "$@" >> "$LOGFILE"
  fi
}

function run_ssh_potbuilder {
  if [ $DEBUG -eq 1 ]; then
    ssh -F "$SSHCONF_POTBUILDER" "$POTBUILDER" -- "$@" | tee -a "$LOGFILE"
    return "${PIPESTATUS[0]}"
  else
    ssh -F "$SSHCONF_POTBUILDER" "$POTBUILDER" -- "$@" >> "$LOGFILE"
  fi
}

function run_ssh_pottery {
  if [ $DEBUG -eq 1 ]; then
    ssh -F "$SSHCONF_POTTERY" "$POTTERY" -- "$@" | tee -a "$LOGFILE"
    return "${PIPESTATUS[0]}"
  else
    ssh -F "$SSHCONF_POTTERY" "$POTTERY" -- "$@" >> "$LOGFILE"
  fi
}
