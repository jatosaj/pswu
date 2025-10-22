#!/bin/bash

# Define number of drives
1=${1}

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
    echo -en '\n'
    echo "Usage: ${0} NUMBER_OF_DRIVES"
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
    # Shift down parameter
    set -- $(($1-1))
    # Run short captive smart test
    smartctl -C -t short "/dev/sg${1}"
    # Format drive to 512b
    sg_format --format --size=512 "/dev/sg${1}"
    # Read S.M.A.R.T values, skip two first lines and send the output to printer wuth font Courier 9px wide and 10px high
    sudo smartctl -a "/dev/sg${1}" | tail -n +3 | enscript -B -f Courier9/10
    echo "Printing report for drive: sg${1}"

done
exit 0
