#!/bin/bash

# --- Function Definitions ---

# Function to display a simple spinner animation
show_spinner() {
  local pid=$1
  local spin='\|/-'
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    i=$(( (i+1) % 4 ))
    printf "\r${spin:$i:1}"
    sleep .1
  done
  printf "\r \r"
}

# Function to create an installer
create_installer() {
  local version=$1
  local app_path="/Applications/Install macOS ${version}.app"
  local volume_path="/Volumes/Install macOS ${version}" # Use a consistent volume name

  # Check if the installer app exists
  if [ ! -d "$app_path" ]; then
    echo "Warning: Installer for macOS ${version} not found at $app_path. Skipping."
    return
  fi

  # Confirm the target volume exists
  if [ ! -d "$volume_path" ]; then
    echo "Error: Target volume $volume_path for macOS ${version} not found. Skipping."
    return
  fi

  echo "Creating installer for macOS ${version}..."
  
  # Run the createinstallmedia command with full redirection
  #< sudo "$app_path/Contents/Resources/createinstallmedia" --volume "$volume_path" --nointeraction &
  #local pid=$! | \
   #   grep -v "Copying installer files" | \
    #  grep -v "Ready to start." | \
     # grep -v "Copying the macOS RecoveryOS..." | \
      #grep -v "Making disk bootable..." | \
      #grep -v "%..." &
  
  sudo "$app_path/Contents/Resources/createinstallmedia" --volume "$volume_path" <<< y 2>&1 & \
      grep -v "Erasing disk: " | \
      grep -v "Copying installer files" | \
      grep -v "Ready to start." | \
      grep -v "Copying the macOS RecoveryOS..." | \
      grep -v "Making disk bootable..." | \
      grep -v "%..." &
      local pid=$!
  # Show the spinner for the current background process
  show_spinner "$pid"
  
  # Wait for the specific process to finish
  wait "$pid"
  
  if [ $? -eq 0 ]; then
    echo "Success: Installer for macOS ${version} created."
  else
    echo "Error: Failed to create installer for macOS ${version}."
  fi
}

# --- Main Script ---

# Check for root
if [ "$(id -u)" -ne 0 ]; then
   echo "This script must be run as root."
   exit 1
fi

echo "Starting macOS installer creation process."

# List of macOS versions to create installers for
macos_versions=(
  "Tahoe"
  "Sequoia"
  "Sonoma"
  "Ventura"
  "Monterey"
)

# Iterate through the list and create installers one by one
for version in "${macos_versions[@]}"; do
  create_installer "$version"
done

echo "All installer creation processes have finished."
exit 0
