# potman

Build [pots](https://github.com/pizzamig/pot) easily.

Uses [Potluck](https://potluck.honeyguide.net) templates, see also
the [Potluck Flavour Repository](https://github.com/hny-gd/potluck) and
[FreeBSD Virtual DC with Potluck](https://honeyguide.eu/posts/virtual-dc1/).

## Quickstart
To create your own kiln, init the VMs, build and deploy an example image:

    git clone https://github.com/grembo/potman
    cd potman
    export PATH=$(pwd)/bin:$PATH
    potman init -d "$(pwd)/flavours" mykiln
    cd mykiln
    potman packbox
    potman startvms
    potman build example
    potman publish example
    potman catalog
    potman deploy example
    ...
    potman status
    potman nomad status example
    potman nomad logs 2fbb4207
    potman nomad logs -f -stderr 2fbb4207
    ...

This might take a while when run for the first time.

## Troubleshoot Vagrant

In case your cannot start vagrant/virtualbox VMs due to this error:

    Vagrant failed to properly resolve required dependencies. These
    errors can commonly be caused by misconfigured plugin installations
    or transient network issues. The reported error is:

    conflicting dependencies net-ssh (= 6.1.0) and net-ssh (= 7.2.0)
      Activated net-ssh-7.2.0
      which does not match conflicting dependency (= 6.1.0)

      Conflicting dependency chains:
        net-ssh (= 7.2.0), 7.2.0 activated

      versus:
        net-ssh (= 6.1.0)

      Gems matching net-ssh (= 6.1.0):
        net-ssh-6.1.0

You can use the following workaround:

    export VAGRANT_DISABLE_STRICT_DEPENDENCY_ENFORCEMENT=1
    potman startvms


## Building Your Own Flavour

Create your own flavour like described in
[this howto](https://potluck.honeyguide.net/howto/) and place it
in the ./flavours directory of your kiln.

    potman init mykiln
    cd mykiln
    potman packbox
    potman startvms
    ls flavours
    ...

## Stopping

    potman stopvms

## Destroying

    potman destroyvms

## Dependencies

potman requires
- ansible
- bash
- git
- packer
- vagrant
- virtualbox

Installing these depends on your OS/distribution, on FreeBSD the procedure
is:

    pkg install bash git packer py39-ansible py39-packaging \
      vagrant virtualbox-ose
    service vboxnet enable
    service vboxnet start

Make sure your username is added to the `vboxusers` group to run 
VirtualBox, on FreeBSD the procedure is:

    (sudo) pw groupmod vboxusers -m <username>

Set the valid ranges for Virtualbox in `/usr/local/etc/vbox/networks.conf`:

    mkdir -p /usr/local/etc/vbox
    echo "* 10.100.1.0/24" >>/usr/local/etc/vbox/networks.conf

Note: Prior to virtualbox-ose port version 6.1.32_1, networks.conf
is expected to reside in /etc/vbox/networks.conf. The vagrant port
on FreeBSD also expects the file to exist there at the time of writing,
so it's best to symlink the directory:

    cd /etc
    ln -s ../usr/local/etc/vbox .

To make the path addition permanent, add the following to .profile (or 
similar) for your shell:

    PATH=/home/<username>/potman/bin:$PATH; export PATH

## Usage

    Usage: potman command [options]

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

## Howto: Building a Potluck Flavour

In the example below, we're building the git-nomad flavour.

Get potluck:

    git clone https://github.com/hny-gd/potluck

Prepare potman:

    git clone https://github.com/grembo/potman
    cd potman
    export PATH=$(pwd)/bin:$PATH

Prepare your kiln:

    potman init mykiln
    cd mykiln
    potman packbox
    potman startvms

Build the base image used in the origin and publish it to the pottery:

    potman build -v -d ../flavours freebsd
    potman publish -v -d ../flavours freebsd
    potman catalog

This base image can be used as a shared basis for all potluck images to
reduce their size and speed up build/deployment.

Construct a compatible flavour from the potluck flavour:

    cp -a ../../potluck/git-nomad flavours/.
    touch flavours/git-nomad/git-nomad
    mkdir flavours/git-nomad/git-nomad.d
    touch flavours/git-nomad/git-nomad.d/distfile.tar
    cat>flavours/git-nomad/git-nomad.ini<<EOF
    [manifest]
    potname="git-nomad"
    author="Potluck Contributors"
    version="1.0"
    origin="freebsd"
    runs_in_nomad="true"
    EOF

Build and publish the git-nomad pot, then check the pottery catalog:

    potman build -v git-nomad
    potman publish -v git-nomad
    potman catalog

Create a nomad job description (this is hacky, best to check the resulting
file):

    cat ../flavours/example/example.d/minipot.job |\
      sed "s/example/git-nomad/g" |\
      sed "s/http/ssh/g" |\
      sed "s/\"80\"/\"22\"/" \
      >flavours/git-nomad/git-nomad.d/minipot.job

Deploy the pot:

    potman deploy -v git-nomad

And, finally, perceive the job status:

    potman status
    potman nomad status git-nomad

You can use

    potman nomad logs <alloc_id>
    potman nomad logs -stderr <alloc_id>

to get log output of the nomad job and

    potman nomad alloc status <alloc_id>

to learn about its endpoints.

_Note: This doesn't make use of the stripping down step of the potluck
flavour (git-nomad.sh+3), instead it uses the intermediate base image, which
more potluck images can be based on._
