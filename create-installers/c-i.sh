#!/bin/bash

#Check for root
if ! [ $(id -u) = 0 ]; then
   echo "Must run as root !"
   exit 1
fi

echo "Creating installers"

# List of macOS versions to create installers for
macos_versions=(
  "Tahoe"
  "Sequoia"
  "Sonoma"
  "Ventura"
  "Monterey"
)

# Function to create an installer
create_installer() {
  local version=$1
  local app_path="/Applications/Install macOS ${version}.app"
  local volume_path="/Volumes/Install macOS ${version}"

  # Check if the installer app exists
  if [ -d "$app_path" ]; then
    echo "Creating installer for macOS ${version}..."
    "$app_path/Contents/Resources/createinstallmedia" --volume "$volume_path" <<< y 2>&1 & \
    #"$app_path/Contents/Resources/createinstallmedia" --nointeraction --volume "$volume_path" 2>&1 | \
    #"$app_path/Contents/Resources/createinstallmedia" --volume "$volume_path" --nointeraction | \
      grep -v "Erasing disk: " | \
      grep -v "Copying installer files" | \
      grep -v "Ready to start." | \
      grep -v "Copying the macOS RecoveryOS..." | \
      grep -v "Making disk bootable..." | \
      grep -v "%..." &
  else
    echo "Warning: Installer for macOS ${version} not found at $app_path"
  fi
}

# Wait for all background jobs to finish
wait

echo "Done"

exit 0

