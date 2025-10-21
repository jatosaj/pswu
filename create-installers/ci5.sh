#!/bin/bash

# Check for root privileges
if (( EUID != 0 )); then
   echo "Error: This script must be run as root." >&2
   exit 1
fi

# Function to display a spinner while a process is running
spinner() {
    local pid=$1
    local spin='\|/-' # Braille spinner characters
    local i=0
    while ps -p "$pid" > /dev/null; do
        i=$(( (i+1) % ${#spin} ))
        printf "\r[%c] " "${spin:$i:1}"
        sleep 0.1
    done
    printf "\r[✔] Done\n"
}

# --- Main Script ---
echo "Starting macOS installer creation..."

# Array of macOS versions to process
versions=("Tahoe" "Sequoia" "Sonoma" "Ventura" "Monterey")

# Loop through each version
for version in "${versions[@]}"; do
    installer_app="/Applications/Install macOS $version.app"
    volume_path="/Volumes/Install macOS $version"

    # Check if the installer application and volume exist first
    if [[ ! -d "$installer_app" || ! -d "$volume_path" ]]; then
        echo "Skipping $version: Installer app or volume not found."
        continue
    fi

    echo -n "Creating macOS $version installer..."

    # Run the createinstallmedia command in the background
    # All output (stdout & stderr) is redirected to /dev/null
    # The 'y' is passed to stdin to automatically confirm erasing the volume
    "$installer_app/Contents/Resources/createinstallmedia" --volume "$volume_path" <<< y  & #&> /dev/null 

    # Display the spinner for the process we just started ($!)
    spinner $!
done

echo "All tasks completed."
exit 0