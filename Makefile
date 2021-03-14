FLAVOUR?=	example

all: check-commands buildbox startvms buildpot publishpot testpot

check-commands:
	# check if required tools are available
	@ansible --version >/dev/null
	@bash --version >/dev/null
	@git --version >/dev/null
	@packer --version >/dev/null
	@vagrant --version >/dev/null
	@vboxheadless --version >/dev/null

buildbox:
	# make sure box is available
	@(vagrant box list | grep "FreeBSD-12.2-RELEASE-amd64" |\
	  grep "virtualbox" >/dev/null) || ./boxbuild.sh

startvms:
	# up/provision VMs
	@(vagrant plugin list | grep "vagrant-disksize" >/dev/null)\
	  || vagrant plugin install vagrant-disksize
	vagrant up

buildpot:
	# build example pot image
	./potbuild.sh -v ${FLAVOUR}

publishpot:
	./potpublish.sh -v ${FLAVOUR}

testpot:
	./pottest.sh -v ${FLAVOUR}

stopvms:
	# shutdown vms
	vagrant halt

status:
	vagrant status

clean:
	rm -rf _build

destroyvm:
	vagrant destroy -f

removebox:
	@(vagrant box list | grep "FreeBSD-12.2-RELEASE-amd64" |\
	  grep "virtualbox" >/dev/null) && (vagrant box remove \
	  -f --provider virtualbox FreeBSD-12.2-RELEASE-amd64) || true

distclean: clean destroyvm removebox
