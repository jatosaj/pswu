#!/bin/bash

# --- Configuration ---
# Array of macOS versions (the names MUST match the application names exactly)
declare -a os_versions=(
    "Sequoia"
    "Sonoma"
    "Ventura"
    "Monterey"
)
# Name of the install media tool
TOOL_NAME="createinstallmedia"
# Path to the base command
BASE_COMMAND_PATH="/Applications"
# Array to store PIDs of all background jobs
declare -a PIDS=()

# --- Functions ---

# Function to check for root privileges
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "🛑 ERROR: This script must be run as root (using sudo)." >&2
        exit 1
    fi
}

# Function to run the installer command with filtering
run_installer_command() {
    local os_version="$1"
    local app_path="${BASE_COMMAND_PATH}/Install macOS ${os_version}.app"
    local volume_path="/Volumes/Install macOS ${os_version}"
    local full_command="${app_path}/Contents/Resources/${TOOL_NAME}"

    echo "⚙️  Attempting to start: macOS ${os_version} installer..."

    # Check if the application exists before trying to run it
    if [[ ! -d "${app_path}" ]]; then
        echo "⚠️  WARNING: Installer app not found for macOS ${os_version}. Skipping."
        return 1
    fi

    # The actual command run in the background (&).
    # Corrected I/O redirection: 2>&1 redirects stderr to stdout. 
    # The 'grep -v' chain is simplified using 'egrep' (or 'grep -E') with regex alternation.
    "${full_command}" --volume "${volume_path}" <<< y 2>&1 \
    | egrep -v 'Erasing disk: |[0-9]{1,3}%\.\.\. ' &
    
    # Store the Process ID (PID) of the background job
    PIDS+=($!)
    echo "   Process ID (PID) for ${os_version}: ${PIDS[-1]} started."
}

# --- Main Script Execution ---

check_root

echo "------------------------------------------------------------------"
echo "🚀 Starting parallel creation of ${#os_versions[@]} macOS installers..."
echo "------------------------------------------------------------------"

# Loop through the array and start each installer creation process
for version in "${os_versions[@]}"; do
    run_installer_command "$version"
done

# Check if any processes were actually started
if [ ${#PIDS[@]} -eq 0 ]; then
    echo "❌ No installer processes were started. Check that your macOS apps are in /Applications."
    exit 1
fi

echo "------------------------------------------------------------------"
echo "✅ All requested installer commands have been started in the background."
echo "⏳ Waiting for all background installer processes to complete..."

# Wait for all background processes stored in the PIDS array to finish
wait "${PIDS[@]}"

echo "------------------------------------------------------------------"
echo "🎉 Installer creation complete for all available versions!"

exit 0