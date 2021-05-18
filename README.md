# potman

Build [pots](https://github.com/pizzamig/pot) easily.

Uses [Potluck](https://potluck.honeyguide.net) templates, see also
the [Potluck Flavour Repository](https://github.com/hny-gd/potluck) and
[FreeBSD Virtual DC with Potluck](https://honeyguide.eu/posts/virtual-dc1/).

## Quickstart

To create your own kiln, init the VMs, build and deploy an example image:

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

This might take a while when run for the first time.

## Building Your Own Flavour

Create your own flavour like described in
[this howto](https://potluck.honeyguide.net/howto/) and place it
in the ./flavours directory of your kiln.

    potman init mykiln
    cd mykiln
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

    pkg install bash git packer py37-ansible vagrant virtualbox-ose
    service vboxnet enable
    service vboxnet start

## Usage

    Usage: potman command

    Commands:

        build       -- Build a flavour
        catalog     -- See catalog contents
        deploy      -- Test deploy image
        destroyvms  -- Destroy VMs
        help        -- Show usage
        init        -- Initialize new kiln
        nomad       -- run nomad in minipot
        packbox     -- Create vm box image
        prune       -- Reclaim disk space
        publish     -- Publish image to pottery
        startvms    -- Start (and provision) VMs
        status      -- Show status
        stopvms     -- Stop VMs
