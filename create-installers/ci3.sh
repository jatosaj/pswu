#!/bin/bash

# Check for root - using modern [[ ... ]] and -ne for numerical comparison
if [[ $(id -u) -ne 0 ]]; then
   echo "Must run as root!"
   exit 1
fi

echo "Creating installers..."

# List of macOS versions to create installers for
macos_versions=(
  "Tahoe"
  "Sequoia"
  "Sonoma"
  "Ventura"
  "Monterey"
)

# A global variable to hold the PID of the last started process
pid=""

# Function to create an installer
create_installer() {
  local version=$1
  local app_path="/Applications/Install macOS ${version}.app"
  local volume_path="/Volumes/Install macOS ${version}"

  # Check if the installer app exists - using modern [[ ... ]]
  if [[ -d "$app_path" ]]; then
    echo "Starting installer for macOS ${version} in the background..."
    
    # --- CORRECTED LINE ---
    # The command pipeline is now syntactically correct.
    # 1. '<<< "y"' provides input to the createinstallmedia command.
    # 2. '2>&1' redirects standard error to standard out so 'grep' can filter it.
    # 3. The entire pipeline is sent to the background with a single '&' at the end.
    # A better alternative to '<<< "y"' is the --nointeraction flag if available.
    "$app_path/Contents/Resources/createinstallmedia" --volume "$volume_path" <<< "y" 2>&1 | \
      grep -v "Erasing disk: " | \
      grep -v "Copying installer files" | \
      grep -v "Ready to start." | \
      grep -v "Copying the macOS RecoveryOS..." | \
      grep -v "Making disk bootable..." | \
      grep -v "%..." &

    # Capture the PID of the last backgrounded process pipeline
    pid=$!
    
  else
    echo "Warning: Installer for macOS ${version} not found at $app_path"
  fi
}

# Iterate through the list and create installers
for version in "${macos_versions[@]}"; do
  create_installer "$version"
done

# Create a spinner animation.
# NOTE: This will only track the *last* installer process that was started,
# as the 'pid' variable is overwritten in each loop iteration.
if [[ -n "$pid" ]]; then
    echo "Displaying progress for the last process (PID: $pid)..."
    i=1
    sp="\|/-"
    while ps -p $pid > /dev/null; do
        printf "\b%c" "${sp:i++%4:1}"
        sleep 0.1
    done
    printf "\nLast process finished!\n"
fi

# Wait for ALL background jobs to finish before exiting
echo "Waiting for all remaining installer processes to complete..."
wait

echo "Done."

exit 0