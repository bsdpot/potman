#!/usr/bin/env bash

if [ -z "$BASH_VERSION" ]; then
  >&2 echo "This needs to run in bash"
  exit 1
fi

usage()
{
  echo "Usage: potman packbox [-hv]"
}

OPTIND=1
while getopts "hv" _o ; do
  case "$_o" in
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

if [ $# -ne 0 ]; then
  usage
  exit 1
fi

set -eE
trap 'echo error: $STEP failed' ERR
source "${INCLUDE_DIR}/common.sh"
common_init_vars
exit_if_vmm_loaded

mkdir -p _build

step "Start"
mkdir -p _build
read_potman_config potman.ini
FREEBSD_VERSION="${config_freebsd_version}"

# disables packer telemetry
export CHECKPOINT_DISABLE=1

step "Check tooling"
ansible --version >/dev/null
git --version >/dev/null
packer --version >/dev/null
vagrant --version >/dev/null
vboxheadless --version >/dev/null
VBOX_MAJOR_VERSION=$(vboxmanage --version | awk -F\. '{ print $1 }')

step "Check box already exists"
if vagrant box list | grep "FreeBSD-${FREEBSD_VERSION}-RELEASE-amd64" |\
	  grep "virtualbox" >/dev/null; then
  step "Box already exists"
  exit 0
fi

step "Initialize"

rm -rf _build/packer
git clone https://github.com/jlduran/packer-FreeBSD.git _build/packer

cd _build/packer
git checkout fe352a349f744d0ce2b5bbde5b84526df041e435

{
  printf "\n# Enable resource limits\n"
  printf "echo kern.racct.enable=1 >>/boot/loader.conf\n"
  printf "\n# Growfs on first boot\n"
  printf "service growfs enable\n"
  printf "touch /firstboot\n"
} >>scripts/cleanup.sh

# patch away dependency on qemu plugin
sed -i '' '/qemu =/,+3 d' packer.pkr.hcl
sed -i '' '/source.qemu.freebsd/ d' packer.pkr.hcl

# allow for longer boot time on slow vms
sed -i '' 's/wait15s/wait45s/g' packer.pkr.hcl

# installs missing plugins
packer init .

<variables.pkrvars.hcl.sample \
  sed "s/13\.2/${FREEBSD_VERSION}/g" >variables.pkrvars.hcl

if [ "$VBOX_MAJOR_VERSION" -lt 7 ]; then
  PACKERPATH="$POTMAN_BIN_DIR:$PATH"
else
  PACKERPATH="$PATH"
fi

PATH="$PACKERPATH" \
  packer build \
    -only=virtualbox-iso.freebsd \
    -var-file=variables.pkrvars.hcl .

vagrant box add "builds/FreeBSD-${FREEBSD_VERSION}-RELEASE-amd64.box" \
  --name "FreeBSD-${FREEBSD_VERSION}-RELEASE-amd64"

step "Success"
