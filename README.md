# potman

Build [pots](https://github.com/pizzamig/pot) easily.

Uses [Potluck](https://potluck.honeyguide.net) templates, see also
the [Potluck Flavour Repository](https://github.com/hny-gd/potluck) and
[FreeBSD Virtual DC with Potluck](https://honeyguide.eu/posts/virtual-dc1/).

## Preparation 
Make sure your username is added to the `vboxusers` group to run VirtualBox:

    (sudo) pw groupmod vboxusers -m <username>

Set the valid ranges for Virtualbox in `/etc/vbox/networks.conf`:

    mkdir -p /etc/vbox
    vi /etc/vbox/networks.conf

    (add, with asterisk)

    * 10.100.0.0/16

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

To make the path addition permanent, add the following to your .profile (or similar) for your shell:

    PATH=/home/<username>/potman/bin:$PATH; export PATH

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

    pkg install bash git packer py38-ansible py38-packaging \
      vagrant virtualbox-ose
    service vboxnet enable
    service vboxnet start

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
