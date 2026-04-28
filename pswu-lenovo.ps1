# --- CONFIGURATION VARIABLES ---
# This is pswu configured as default for Lenovo. It installs Lenovo Vantage

$TotalReboots = 1                          # Total number of times the script should reboot the machine
$DeviceInstanceID = ""                     # Fill this in later, but leave it uncommented!
$DriverINF = ""                            # Fill this in later, but leave it uncommented!
$Destination = "$env:ProgramData\pswu.ps1" # The location where the persistent script will be saved
$LogPath = "$env:ProgramData\pswu_log.txt" # The location where the script will write its log file
$StoreInstall = "9WZDNCRFJ4MV"             # The additional software ID

# --- SCRIPT CONTENT TO BE RUN ON EVERY REBOOT ---
$ScriptContent = @"
`$RegPath = 'HKLM:\SOFTWARE\PSWU'
`$LogFile = '$LogPath'
`$CurrentCount = 0

function Write-Log {
    param(`$Message)
    `$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[`$Timestamp] `$Message" | Out-File -FilePath `$LogFile -Append
}

try {
    `$CurrentCount = [int](Get-ItemProperty -Path `$RegPath -Name 'RebootCount' -ErrorAction Stop).RebootCount
} catch {
    `$CurrentCount = 1
}

Write-Log "Starting Cycle: `$CurrentCount"

if (`$CurrentCount -gt 1) {
    # Still in loop: Decrement and Re-arm
    `$NewCount = `$CurrentCount - 1
    Set-ItemProperty -Path `$RegPath -Name 'RebootCount' -Value `$NewCount
    
    `$RunOnceKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
    `$Command = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$Destination"'
    New-ItemProperty -Path `$RunOnceKey -Name 'PSWU_RunAfterReboot' -Value `$Command -PropertyType String -Force
} else {
    # Final pass: Cleanup
    Write-Log "Final pass detected. Cleaning up device/drivers."
    
    if ("$DeviceInstanceID") { pnputil /remove-device "$DeviceInstanceID" | Out-Null }
    if ("$DriverINF") { pnputil /delete-driver $DriverINF /uninstall /force | Out-Null }
    
    Remove-Item -Path `$RegPath -Recurse -ErrorAction SilentlyContinue
}

try {
    Import-Module PSWindowsUpdate
    Write-Log "Running Install-WindowsUpdate..."
    Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot -ErrorAction Stop
} catch {
    `$ErrMsg = `$_.Exception.Message
    Write-Log "ERROR: `$ErrMsg"
    if (`$ErrMsg -match "expected range") {
        Write-Log "Known WU error detected. Resetting components."
        Reset-WUComponents -Confirm:`$false
    }
}

if (`$CurrentCount -gt 1) {
    Write-Log "Rebooting for next cycle."
    Start-Sleep -Seconds 5
    Restart-Computer -Force
} else {
    Write-Log "Sequence Complete."
    Add-Type -AssemblyName System.Speech
    (New-Object System.Speech.Synthesis.SpeechSynthesizer).Speak('Sequence finished and logged')
}
"@

# --- INITIAL SETUP & EXECUTION ---
# Create the script and hide it
Set-Content -Path $Destination -Value $ScriptContent
Set-ItemProperty -Path $Destination -Name Attributes -Value Hidden

# Initialize log
"$(Get-Date): Script Initialized" | Out-File -FilePath $LogPath

# Setup registry counter
$RegPath = "HKLM:\SOFTWARE\PSWU"
if (!(Test-Path $RegPath)) { New-Item -Path $RegPath -Force | Out-Null }
Set-ItemProperty -Path $RegPath -Name "RebootCount" -Value $TotalReboots

# Set RunOnce for the first reboot
$RunOnceKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
$Command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$Destination`""
New-ItemProperty -Path $RunOnceKey -Name "PSWU_RunAfterReboot" -Value $Command -PropertyType String -Force

# Set monitor timeout
PowerCFG -Change -Monitor-Timeout-AC 0

# 1. RUN STORE INSTALL FIRST
Write-Output "Step 1: Installing Software ID: $StoreInstall..."
Store Install $StoreInstall

# 2. SETUP WINDOWS UPDATE MODULE
if (!(Get-Module -ListAvailable PSWindowsUpdate)) {
    Write-Output "Step 2: Installing PSWindowsUpdate module..."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
    Install-Module PSWindowsUpdate -Force -SkipPublisherCheck
}

# 3. RUN INITIAL UPDATES
Import-Module PSWindowsUpdate
Write-Output "Step 3: Initial updates starting. Check $LogPath for details."
# -AutoReboot will handle the restart if updates are installed.
Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot 

# Final safety check: If no updates were found, we manually reboot to start the loop logic.
Write-Output "Initial tasks complete. Proceeding to first reboot..."
Start-Sleep -Seconds 5
Restart-Computer -Force