#!/usr/bin/env bash

set -e

VERSION_REGEX='^[0-9](.[0-9a-zA-Z]+)*$'

# Hacky, needs to be replaced
function read_ini_file()
{
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

function read_flavour_config {
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
}
