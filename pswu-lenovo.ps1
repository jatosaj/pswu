# --- CONFIGURATION VARIABLES ---
$TotalReboots = 1                          
$DeviceInstanceID = ""                     
$DriverINF = "oem93.inf"                   
$Destination = "$env:ProgramData\pswu.ps1" 
$LogPath = "$env:ProgramData\pswu_log.txt" 
$StoreInstall = "9WZDNCRFJ4MV"             

# --- INITIAL LOGGING ---
function Write-Log {
    param($Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$Timestamp] $Message" | Out-File -FilePath $LogPath -Append
}

Write-Log "Initial Setup Started."

# --- PERSISTENT SCRIPT (Runs on reboots) ---
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
    # --- INTERMEDIATE PASS LOGIC ---
    `$NewCount = `$CurrentCount - 1
    Set-ItemProperty -Path `$RegPath -Name 'RebootCount' -Value `$NewCount
    `$RunOnceKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
    `$Command = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$Destination"'
    New-ItemProperty -Path `$RunOnceKey -Name 'PSWU_RunAfterReboot' -Value `$Command -PropertyType String -Force
} else {
    # --- FINAL PASS LOGIC ---
    Write-Log "Final pass detected. Running Store Install and Cleanup."

    # Direct command as requested
    store install $StoreInstall

    # Cleanup Drivers/Devices
    if ("$DeviceInstanceID") { pnputil /remove-device "$DeviceInstanceID" | Out-Null }
    if ("$DriverINF") { pnputil /delete-driver $DriverINF /uninstall /force | Out-Null }
    
    Remove-Item -Path `$RegPath -Recurse -ErrorAction SilentlyContinue
}

# --- WINDOWS UPDATE BLOCK ---
try {
    Import-Module PSWindowsUpdate
    Write-Log "Checking for updates..."
    Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot -ErrorAction Stop
} catch {
    `$ErrMsg = `$_.Exception.Message
    Write-Log "UPDATE ERROR: `$ErrMsg"
    if (`$ErrMsg -match "expected range") {
        Write-Log "Fixing WU Database..."
        Reset-WUComponents -Confirm:`$false
    }
}

if (`$CurrentCount -gt 1) {
    Write-Log "Rebooting for next pass."
    Start-Sleep -Seconds 5
    Restart-Computer -Force
} else {
    Write-Log "Deployment Sequence Complete."
    Add-Type -AssemblyName System.Speech
    (New-Object System.Speech.Synthesis.SpeechSynthesizer).Speak('Sequence finished.')
}
"@

# --- INITIAL SETUP (Runs once in OOBE) ---
Set-Content -Path $Destination -Value $ScriptContent
Set-ItemProperty -Path $Destination -Name Attributes -Value Hidden

$RegPath = "HKLM:\SOFTWARE\PSWU"
if (!(Test-Path $RegPath)) { New-Item -Path $RegPath -Force | Out-Null }
Set-ItemProperty -Path $RegPath -Name "RebootCount" -Value $TotalReboots

$RunOnceKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
$Command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$Destination`""
New-ItemProperty -Path $RunOnceKey -Name "PSWU_RunAfterReboot" -Value $Command -PropertyType String -Force

PowerCFG -Change -Monitor-Timeout-AC 0

if (!(Get-Module -ListAvailable PSWindowsUpdate)) {
    Write-Log "Setting up PSWindowsUpdate Module..."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
    Install-Module PSWindowsUpdate -Force -SkipPublisherCheck
}

Write-Log "Initial pass complete. Triggering first reboot."
Start-Sleep -Seconds 5
Restart-Computer -Force