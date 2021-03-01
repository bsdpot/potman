all:
	# check if required tools are available
	@ansible --version >/dev/null
	@bash --version >/dev/null
	@git --version >/dev/null
	@packer --version >/dev/null
	@vagrant --version >/dev/null
	@vboxheadless --version >/dev/null

	# make sure box is available
	@(vagrant box list | grep "FreeBSD-12.2-RELEASE-amd64" |\
	  grep "virtualbox" >/dev/null) || ./boxbuild.sh

	# up/provision VMs
	vagrant up
	
	# build example pot image
	./potbuild.sh -v example

	# shutdown vms
	vagrant halt

clean:
	rm -rf _build

distclean: clean
	vagrant destroy -f
	vagrant box remove \
	  -f --provider virtualbox \
	  FreeBSD-12.2-RELEASE-amd64
