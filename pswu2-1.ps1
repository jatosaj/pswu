# This is version 2.1 it creates the log and attempts to self heal if WindowsUpdate gets stuck.
# --- CONFIGURATION ---
$TotalReboots = 2            
$DeviceInstanceID = "foo-bar" 
$DriverINF = "oem93.inf"      
$Destination = "$env:ProgramData\pswu.ps1" 
$LogPath = "$env:ProgramData\pswu_log.txt"

# --- CREATE THE PERSISTENT SCRIPT ---
$ScriptContent = @"
`$RegPath = 'HKLM:\SOFTWARE\PSWU'
`$LogFile = '$LogPath'
`$CurrentCount = 0

# Helper function for logging
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
    `$NewCount = `$CurrentCount - 1
    Set-ItemProperty -Path `$RegPath -Name 'RebootCount' -Value `$NewCount
    
    `$RunOnceKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
    `$Command = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$Destination"'
    New-ItemProperty -Path `$RunOnceKey -Name 'PSWU_RunAfterReboot' -Value `$Command -PropertyType String -Force
} else {
    Write-Log "Final pass detected. Cleaning up device/drivers."
    pnputil /remove-device "$DeviceInstanceID" | Out-Null
    pnputil /delete-driver $DriverINF /uninstall /force | Out-Null
    Remove-Item -Path `$RegPath -Recurse -ErrorAction SilentlyContinue
}

# --- Windows Update with Self-Healing ---
try {
    Import-Module PSWindowsUpdate
    Write-Log "Running Install-WindowsUpdate..."
    Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot -ErrorAction Stop
    Write-Log "Update command executed successfully."
} catch {
    `$ErrMsg = `$_.Exception.Message
    Write-Log "ERROR: `$ErrMsg"
    
    if (`$ErrMsg -match "expected range") {
        Write-Log "Known WU error detected. Triggering Reset-WUComponents."
        Reset-WUComponents -Confirm:`$false
        Write-Log "Components reset. Awaiting next reboot."
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

# --- INITIAL SETUP ---
Set-Content -Path $Destination -Value $ScriptContent
Set-ItemProperty -Path $Destination -Name Attributes -Value Hidden
"$(Get-Date): Script Initialized" | Out-File -FilePath $LogPath

$RegPath = "HKLM:\SOFTWARE\PSWU"
if (!(Test-Path $RegPath)) { New-Item -Path $RegPath -Force | Out-Null }
Set-ItemProperty -Path $RegPath -Name "RebootCount" -Value $TotalReboots

$RunOnceKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
$Command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$Destination`""
New-ItemProperty -Path $RunOnceKey -Name "PSWU_RunAfterReboot" -Value $Command -PropertyType String -Force

# Prerequisites
PowerCFG -Change -Monitor-Timeout-AC 0

if (Get-Command winget -ErrorAction SilentlyContinue) {
    winget install --id 9WZDNCRFJ4MV --accept-package-agreements --accept-source-agreements
}

if (!(Get-Module -ListAvailable PSWindowsUpdate)) {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
    Install-Module PSWindowsUpdate -Force -SkipPublisherCheck
}

Import-Module PSWindowsUpdate
Write-Output "Initial cycle starting. Check $LogPath for progress."
Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot
Start-Sleep -Seconds 5
Restart-Computer -Force