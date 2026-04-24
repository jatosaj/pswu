# --- CONFIGURATION VARIABLES ---
# This is pswu configured as deafult for Lenovo. It installs Lenovo Vantage

$TotalReboots = 1                          # Total number of times the script should reboot the machine
#$DeviceInstanceID = "PLACE_HOLDER"         # The unique Instance ID of the device to be removed. Where to find it: In Device Manager, right-click the device > Properties > Details tab > Select Device instance path from the dropdown.
#$DriverINF = "PLACE_HOLDER"                # The specific INF file name of the driver to be deleted. Where to find it: In Device Manager, right-click the device > Properties > Details tab > Select Inf name from the dropdown. 
$Destination = "$env:ProgramData\pswu.ps1" # The location where the persistent script will be saved
$LogPath = "$env:ProgramData\pswu_log.txt" # The location where the script will write its log file
$StoreInstall = "9WZDNCRFJ4MV"             # The additional software to be installed using the store command. Use the software ID i.e 9WZDNCRFJ4MV

# --- SCRIPT CONTENT TO BE RUN ON EVERY REBOOT ---

# This block creates the script that will be saved to the destination path
$ScriptContent = @"
`$RegPath = 'HKLM:\SOFTWARE\PSWU'
`$LogFile = '$LogPath'
`$CurrentCount = 0

# Helper function to write messages to the log file with a timestamp
function Write-Log {
    param(`$Message)
    `$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[`$Timestamp] `$Message" | Out-File -FilePath `$LogFile -Append
}

# Attempt to read the current reboot count from the registry
try {
    `$CurrentCount = [int](Get-ItemProperty -Path `$RegPath -Name 'RebootCount' -ErrorAction Stop).RebootCount
} catch {
    # Fallback to 1 if the registry key is missing or unreadable
    `$CurrentCount = 1
}

Write-Log "Starting Cycle: `$CurrentCount"

# Check if we are still in the reboot loop (count > 1)
if (`$CurrentCount -gt 1) {
    # Decrement the counter for the next run
    `$NewCount = `$CurrentCount - 1
    Set-ItemProperty -Path `$RegPath -Name 'RebootCount' -Value `$NewCount
    
    # Re-arm the RunOnce registry key so the script runs again after the next reboot
    `$RunOnceKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
    `$Command = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$Destination"'
    New-ItemProperty -Path `$RunOnceKey -Name 'PSWU_RunAfterReboot' -Value `$Command -PropertyType String -Force
} else {
    # If this is the final pass (count = 1), run the cleanup tasks
    Write-Log "Final pass detected. Cleaning up device/drivers."
    
    # Remove the specified device using its Instance ID
    pnputil /remove-device "$DeviceInstanceID" | Out-Null
    
    # Completely delete the driver package from the system
    pnputil /delete-driver $DriverINF /uninstall /force | Out-Null
    
    # Clean up the custom registry key since we are done
    Remove-Item -Path `$RegPath -Recurse -ErrorAction SilentlyContinue
}

# --- WINDOWS UPDATE & SELF-HEALING BLOCK ---
try {
    # Load the module and execute the update process
    Import-Module PSWindowsUpdate
    Write-Log "Running Install-WindowsUpdate..."
    Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot -ErrorAction Stop
    Write-Log "Update command executed successfully."
} catch {
    # If an error occurs, log it
    `$ErrMsg = `$_.Exception.Message
    Write-Log "ERROR: `$ErrMsg"
    
    # If it's the specific "expected range" error, trigger the reset
    if (`$ErrMsg -match "expected range") {
        Write-Log "Known WU error detected. Triggering Reset-WUComponents."
        Reset-WUComponents -Confirm:`$false
        Write-Log "Components reset. Awaiting next reboot."
    }
}

# Handle the reboot logic if the update command didn't force one automatically
if (`$CurrentCount -gt 1) {
    Write-Log "Rebooting for next cycle."
    Start-Sleep -Seconds 5
    Restart-Computer -Force
} else {
    # Final notification when all loops are completely finished
    Write-Log "Sequence Complete."
    Add-Type -AssemblyName System.Speech
    (New-Object System.Speech.Synthesis.SpeechSynthesizer).Speak('Sequence finished and logged')
}
"@

# --- INITIAL SETUP & EXECUTION ---
# Write the script content to the destination file
Set-Content -Path $Destination -Value $ScriptContent
# Hide the script file so it isn't intrusive
Set-ItemProperty -Path $Destination -Name Attributes -Value Hidden

# Initialize the log file
"$(Get-Date): Script Initialized" | Out-File -FilePath $LogPath

# Create the registry key to track the reboot count
$RegPath = "HKLM:\SOFTWARE\PSWU"
if (!(Test-Path $RegPath)) { New-Item -Path $RegPath -Force | Out-Null }
Set-ItemProperty -Path $RegPath -Name "RebootCount" -Value $TotalReboots

# Arm the RunOnce registry key for the very first reboot
$RunOnceKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
$Command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$Destination`""
New-ItemProperty -Path $RunOnceKey -Name "PSWU_RunAfterReboot" -Value $Command -PropertyType String -Force

# Set the monitor timeout to 'Never' when plugged in
PowerCFG -Change -Monitor-Timeout-AC 0

# Execute the software install 
Store Install $StoreInstall

# Check if PSWindowsUpdate is installed; install if missing
if (!(Get-Module -ListAvailable PSWindowsUpdate)) {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
    Install-Module PSWindowsUpdate -Force -SkipPublisherCheck
}

# Import the module and start the initial update cycle
Import-Module PSWindowsUpdate
Write-Output "Initial cycle starting. Check $LogPath for progress."
Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot

# Force a reboot if the update command didn't trigger one
Start-Sleep -Seconds 5
Restart-Computer -Force