#!/bin/bash

# This script creates multiple macOS bootable installers in parallel.
# It captures the output of each process and displays it grouped by installer
# after all processes have completed.

# --- Configuration ---
# Add the names of the macOS versions you want to create installers for.
# This script assumes:
# 1. The installer app is located at "/Applications/Install macOS [Version Name].app"
# 2. The target volume is mounted at "/Volumes/Install macOS [Version Name]"
declare -a MACOS_VERSIONS=("Tahoe" "Sequoia" "Sonoma")

# --- Script Logic ---

# Check for root privileges, as createinstallmedia requires them.
if [[ $(id -u) -ne 0 ]]; then
   echo "This script must be run as root. Please use sudo."
   exit 1
fi

echo "Starting parallel creation of macOS installers..."

# Create a temporary directory to store logs for each process.
# This directory will be automatically removed when the script exits.
LOG_DIR=$(mktemp -d)
trap 'rm -rf -- "$LOG_DIR"' EXIT

# Launch all installer creation processes in the background.
for version in "${MACOS_VERSIONS[@]}"; do
    INSTALLER_APP="/Applications/Install macOS ${version}.app"
    TARGET_VOLUME="/Volumes/Install macOS ${version}"
    LOG_FILE="${LOG_DIR}/${version}.log"

    # Verify that the required app and volume exist before proceeding.
    if [[ ! -d "$INSTALLER_APP" ]]; then
        echo "Error: Installer app not found at '$INSTALLER_APP'" >&2
        continue
    fi
    if [[ ! -d "$TARGET_VOLUME" ]]; then
        echo "Error: Target volume not found at '$TARGET_VOLUME'" >&2
        continue
    fi

    echo "-> Starting process for macOS ${version}."
    # Run the command in a subshell, redirecting all output to its log file.
    # The 'y' is piped to automatically confirm erasing the volume.
    (
      "${INSTALLER_APP}/Contents/Resources/createinstallmedia" --volume "${TARGET_VOLUME}" <<< "y"
    ) &> "$LOG_FILE" &
done

# Wait for all background jobs launched by this script to complete.
echo "All processes are running. Waiting for completion... (This may take a significant amount of time)"
wait

echo -e "\n----------------------------------------------------"
echo "All installer processes have finished."
echo "Displaying captured output for each process:"
echo "----------------------------------------------------"

# Display the grouped output from each log file.
for version in "${MACOS_VERSIONS[@]}"; do
    LOG_FILE="${LOG_DIR}/${version}.log"
    echo -e "\n--- Output for macOS ${version} Installer ---"
    if [[ -f "$LOG_FILE" ]]; then
        cat "$LOG_FILE"
    else
        echo "Log file was not created. The process may have failed to start."
    fi
    echo "--- End of Output for macOS ${version} ---"
done

echo -e "\nScript finished."