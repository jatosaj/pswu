# --- CONFIGURATION VARIABLES ---
# This is pswu configured as default for Lenovo. It installs Lenovo Vantage

$TotalReboots = 1                          # Set to 2 if you want an extra update pass before cleanup
$DeviceInstanceID = ""                     # Add your ID here if needed
$DriverINF = "oem93.inf"                   # The driver to be removed on the final pass
$Destination = "$env:ProgramData\pswu.ps1" # The location for the persistent script
$LogPath = "$env:ProgramData\pswu_log.txt" # Detailed log file
$StoreInstall = "9WZDNCRFJ4MV"             # Lenovo Vantage ID

# --- LOGGING FUNCTION ---
function Write-Log {
    param($Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$Timestamp] $Message" | Out-File -FilePath $LogPath -Append
    Write-Output $Message
}

# Initial delay to ensure the network and services are actually ready
Write-Log "Initializing. Waiting 20s for OOBE background services..."
Start-Sleep -Seconds 20

# --- CREATE THE PERSISTENT SCRIPT CONTENT ---
$ScriptContent = @"
`$RegPath = 'HKLM:\SOFTWARE\PSWU'
`$LogFile = '$LogPath'

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

Write-Log "Cycle Started. Remaining: `$CurrentCount"

if (`$CurrentCount -gt 1) {
    `$NewCount = `$CurrentCount - 1
    Set-ItemProperty -Path `$RegPath -Name 'RebootCount' -Value `$NewCount
    `$RunOnceKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
    `$Command = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$Destination"'
    New-ItemProperty -Path `$RunOnceKey -Name 'PSWU_RunAfterReboot' -Value `$Command -PropertyType String -Force
} else {
    Write-Log "Final cycle cleanup. Removing Drivers/Devices."
    if ("$DeviceInstanceID") { pnputil /remove-device "$DeviceInstanceID" | Out-Null }
    if ("$DriverINF") { pnputil /delete-driver $DriverINF /uninstall /force | Out-Null }
    Remove-Item -Path `$RegPath -Recurse -ErrorAction SilentlyContinue
}

try {
    Import-Module PSWindowsUpdate
    Write-Log "Running Windows Updates..."
    Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot -ErrorAction Stop
} catch {
    `$ErrMsg = `$_.Exception.Message
    Write-Log "UPDATE ERROR: `$ErrMsg"
    if (`$ErrMsg -match "expected range") {
        Write-Log "Triggering WU Self-Healing (Reset-WUComponents)..."
        Reset-WUComponents -Confirm:`$false
    }
}

if (`$CurrentCount -gt 1) {
    Write-Log "Looping: Rebooting computer."
    Start-Sleep -Seconds 5
    Restart-Computer -Force
} else {
    Write-Log "Process Complete."
    Add-Type -AssemblyName System.Speech
    (New-Object System.Speech.Synthesis.SpeechSynthesizer).Speak('Deployment Finished')
}
"@

# --- INITIAL SETUP ---
Write-Log "Saving persistent script to $Destination"
Set-Content -Path $Destination -Value $ScriptContent
Set-ItemProperty -Path $Destination -Name Attributes -Value Hidden

Write-Log "Configuring Registry tracking..."
$RegPath = "HKLM:\SOFTWARE\PSWU"
if (!(Test-Path $RegPath)) { New-Item -Path $RegPath -Force | Out-Null }
Set-ItemProperty -Path $RegPath -Name "RebootCount" -Value $TotalReboots

# Initial RunOnce Setup
$RunOnceKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
$Command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$Destination`""
New-ItemProperty -Path $RunOnceKey -Name "PSWU_RunAfterReboot" -Value $Command -PropertyType String -Force

Write-Log "Disabling monitor timeout..."
PowerCFG -Change -Monitor-Timeout-AC 0

# --- SOFTWARE INSTALLATION ---
Write-Log "Starting Store Install: $StoreInstall"
try {
    Store Install $StoreInstall
    Write-Log "Store command issued."
} catch {
    Write-Log "Store command failed to execute."
}

# --- MODULE PREREQUISITES ---
if (!(Get-Module -ListAvailable PSWindowsUpdate)) {
    Write-Log "Installing NuGet provider..."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
    Write-Log "Installing PSWindowsUpdate Module..."
    Install-Module PSWindowsUpdate -Force -SkipPublisherCheck
}

# --- START UPDATES ---
Write-Log "Importing Module and starting first update pass..."
Import-Module PSWindowsUpdate
Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot

# Manual reboot fallback if updates found nothing
Write-Log "First pass finished. Initializing first reboot."
Start-Sleep -Seconds 5
Restart-Computer -Force