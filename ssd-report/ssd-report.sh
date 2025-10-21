#!/bin/bash

# Make sure the script is being executed with super user privilages
if [[ "${UID}" -ne 0 ]]
  then
    echo 'Please run with sudo or as root.'
    exit 1
  fi

# Supply the argument
if [[ "${#}" -lt 1 ]]
  then
    echo "Provide the number of drives to format"
    echo "Usage: ${0} NUMBER_OF_DRIVESecho"
    exit 1
  fi

# Refuse more then one argument
if [[ "${#}" -gt 1 ]]
  then
    echo "Too many arguments"
    echo -en '\n'
    echo "Usage: ${0} NUMBER_OF_DRIVES"
    exit 1
  fi

# Loop trough the drives
while [[ "${1}" -gt 0 ]]
  do

# Run smartmon test and print results
sudo smartctl -a "/dev/sg${1}" | tail -n +3 | enscript -B -f Courier9/10
# Format drive to 512b

echo "Parameter: ${1}"
set -- $(($1-1))
done

