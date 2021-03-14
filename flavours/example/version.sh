#!/bin/sh

SCRIPTPATH=$(dirname "$(readlink -f "$0")")
head -n 1 "$SCRIPTPATH"/example.d/CHANGELOG.md
