# potman

Build pots easily.

## Quickstart

To start the build, simply type

    make

This might take a long time.

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

  