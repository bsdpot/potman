#!/usr/bin/env bash

if [ -z "$BASH_VERSION" ]; then
  >&2 echo "This needs to run in bash"
  exit 1
fi

LOGFILE=$(pwd)/_build/boxbuild.log
#FBSD=12.2
#FBSD_TAG=12_2
#DATE=$(date "+%Y-%m-%d")
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

function step {
  ((STEPCOUNT+=1))
  STEP="$*"
  echo "$STEP" >> "$LOGFILE"
  [ $VERBOSE -eq 0 ] || echo "$STEPCOUNT. $STEP"
}

mkdir -p _build

step "Initialize"

rm -rf _build/packer
git clone https://github.com/jlduran/packer-FreeBSD.git _build/packer

cd _build/packer
git checkout 517f434bd960f97552a8fb6cd35f3cd2de09c492

{
  printf "\n# Enable resource limits\n"
  printf "echo kern.racct.enable=1 >>/boot/loader.conf\n"
  printf "\n# Growfs on first boot\n"
  printf "service growfs enable\n"
  printf "touch /firstboot\n"
} >>scripts/cleanup.sh

cp variables.json.sample variables.json
packer build -var-file=variables.json template.json
vagrant box add builds/FreeBSD-12.2-RELEASE-amd64.box \
  --name FreeBSD-12.2-RELEASE-amd64

step "Success"
