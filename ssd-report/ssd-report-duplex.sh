#!/bin/bash

# Define number of drives
NO_OF_REPORTS=${1}

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
    # Run short captive smart test
    smartctl -C -t short "/dev/sg${1}" > /dev/null
    # Read S.M.A.R.T values, skip two first lines and send the output to printer with font Courier 9px wide and 10px high and print it using lpr duplex mode
    sudo smartctl -a "/dev/sg${1}" | tail -n +3 | enscript -B -f Courier9/10 -p- | lpr -o sides=two-sided-long-edge
    echo "Printing report for drive: sg${1}"
    # Shift down parameter
    set -- $(($1-1))
done

echo "$NO_OF_REPORTS reports has been printed"
exit 0
