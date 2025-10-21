#!/bin/bash

#Check for root
if ! [ $(id -u) = 0 ]; then
   echo "Must run as root !"
   exit 1
fi

echo "Creating installers"
# Create macOS Tahoe installer
/Applications/Install\ macOS\ Tahoe.app/Contents/Resources/createinstallmedia --volume /Volumes/Install\ macOS\ Tahoe <<< y 2>&1 /dev/null | grep -v "Erasing disk: " | grep -v "10%... " | grep -v "20%... " | grep -v "30%..." | grep -v "40%..." | grep -v "50%..." | grep -v "60%..." | grep -v "70%..." | grep -v "80%..." | grep -v "90%..." | grep -v "100%..." &

# Create macOS Sequoia installer
/Applications/Install\ macOS\ Sequoia.app/Contents/Resources/createinstallmedia --volume /Volumes/Install\ macOS\ Sequoia <<< y 2>&1 /dev/null | grep -v "Erasing disk: " | grep -v "10%... " | grep -v "20%... " | grep -v "30%..." | grep -v "40%..." | grep -v "50%..." | grep -v "60%..." | grep -v "70%..." | grep -v "80%..." | grep -v "90%..." | grep -v "100%..." &

# Create macOS Sonoma installer
/Applications/Install\ macOS\ Sonoma.app/Contents/Resources/createinstallmedia --volume /Volumes/Install\ macOS\ Sonoma <<< y 2>&1 /dev/null | grep -v "Erasing disk: " | grep -v "10%... " | grep -v "20%... " | grep -v "30%..." | grep -v "40%..." | grep -v "50%..." | grep -v "60%..." | grep -v "70%..." | grep -v "80%..." | grep -v "90%..." | grep -v "100%..." &

# Create macOS Ventura installer
/Applications/Install\ macOS\ Ventura.app/Contents/Resources/createinstallmedia --volume /Volumes/Install\ macOS\ Ventura <<< y 2>&1 /dev/null | grep -v "Erasing disk: " | grep -v "10%... " | grep -v "20%... " | grep -v "30%..." | grep -v "40%..." | grep -v "50%..." | grep -v "60%..." | grep -v "70%..." | grep -v "80%..." | grep -v "90%..." | grep -v "100%..." &

# Create macOS Monterey installer
/Applications/Install\ macOS\ Monterey.app/Contents/Resources/createinstallmedia --volume /Volumes/Install\ macOS\ Monterey <<< y 2>&1 /dev/null | grep -v "Erasing disk: " | grep -v "10%... " | grep -v "20%... " | grep -v "30%..." | grep -v "40%..." | grep -v "50%..." | grep -v "60%..." | grep -v "70%..." | grep -v "80%..." | grep -v "90%..." | grep -v "100%..." 

echo "Done"

exit 0