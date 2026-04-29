# --- CONFIGURATION ---
$TotalReboots = 1                          
$DeviceInstanceID = ""                     
$DriverINF = ""                   
$DestinationDir = "$env:ProgramData\PSWU"
$Destination = "$DestinationDir\pswu.ps1" 
$LogPath = "$DestinationDir\pswu_log.txt" 
$StoreInstall = "9WZDNCRFJ4MV"             

# --- CRITICAL: Create the directory first ---
if (!(Test-Path $DestinationDir)) { 
    New-Item -ItemType Directory -Path $DestinationDir -Force | Out-Null 
}

# --- INITIAL LOGGING FUNCTION ---
function Write-Log {
    param([string]$Msg, [string]$Level = "INFO")
    $Stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$Stamp] [$Level] $Msg" | Out-File -FilePath $LogPath -Append
}

"------------------------------------------------" | Out-File -FilePath $LogPath -Append
Write-Log "NEW DEPLOYMENT INITIALIZED"

# --- PERSISTENT SCRIPT CONTENT ---
$ScriptContent = @"
`$LogFile = '$LogPath'
`$RegPath = 'HKLM:\SOFTWARE\PSWU'
`$DestDir = '$DestinationDir'

# Ensure directory exists after reboot
if (!(Test-Path `$DestDir)) { New-Item -ItemType Directory -Path `$DestDir -Force | Out-Null }

function Write-Log {
    param([string]`$Msg, [string]`$Level = "INFO")
    `$Stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[`$Stamp] [`$Level] `$Msg" | Out-File -FilePath `$LogFile -Append
}

"--- REBOOT CYCLE STARTED ---" | Out-File -FilePath `$LogFile -Append

try {
    `$CurrentCount = [int](Get-ItemProperty -Path `$RegPath -Name 'RebootCount' -ErrorAction Stop).RebootCount
} catch {
    `$CurrentCount = 1
}

Write-Log "Cycles remaining: `$CurrentCount"

if (`$CurrentCount -gt 1) {
    `$NewCount = `$CurrentCount - 1
    Set-ItemProperty -Path `$RegPath -Name 'RebootCount' -Value `$NewCount
    `$RunOnceKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
    `$Command = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$Destination"'
    New-ItemProperty -Path `$RunOnceKey -Name 'PSWU_RunAfterReboot' -Value `$Command -PropertyType String -Force
} else {
    Write-Log "Final Pass: Store & Cleanup"
    try {
        if (Get-Command "store" -ErrorAction SilentlyContinue) {
            `$StoreResult = store install $StoreInstall *>&1 | Out-String
            Write-Log "STORE OUTPUT:`n`n`$StoreResult" -Level "OUTPUT"
        } else {
            `$ManualPath = (Get-ChildItem -Path "C:\Windows\System32", "C:\Windows\SysWOW64" -Filter "store.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
            if (`$ManualPath) {
                `$StoreResult = & "`$ManualPath" install $StoreInstall *>&1 | Out-String
                Write-Log "STORE OUTPUT:`n`n`$StoreResult" -Level "OUTPUT"
            }
        }
    } catch {
        Write-Log "Store error: `$($_.Exception.Message)" -Level "ERROR"
    }

    if ("$DeviceInstanceID") { pnputil /remove-device "$DeviceInstanceID" 2>&1 | Out-File -FilePath `$LogFile -Append }
    if ("$DriverINF") { pnputil /delete-driver $DriverINF /uninstall /force 2>&1 | Out-File -FilePath `$LogFile -Append }
    
    Remove-Item -Path `$RegPath -Recurse -ErrorAction SilentlyContinue
}

# Windows Update Block
try {
    Import-Module PSWindowsUpdate
    Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot -ErrorAction Stop *>&1 | Out-File -FilePath `$LogFile -Append
} catch {
    Write-Log "Update failed: `$($_.Exception.Message)" -Level "ERROR"
}

if (`$CurrentCount -gt 1) {
    Start-Sleep -Seconds 5
    Restart-Computer -Force
} else {
    Write-Log "SEQUENCE FINISHED."
    Add-Type -AssemblyName System.Speech
    (New-Object System.Speech.Synthesis.SpeechSynthesizer).Speak('Sequence finished.')
}
"@

# --- INITIAL OOBE SETUP ---
Set-Content -Path $Destination -Value $ScriptContent
$RegPath = "HKLM:\SOFTWARE\PSWU"
if (!(Test-Path $RegPath)) { New-Item -Path $RegPath -Force | Out-Null }
Set-ItemProperty -Path $RegPath -Name "RebootCount" -Value $TotalReboots

$RunOnceKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
$Command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$Destination`""
New-ItemProperty -Path $RunOnceKey -Name "PSWU_RunAfterReboot" -Value $Command -PropertyType String -Force

PowerCFG -Change -Monitor-Timeout-AC 0

if (!(Get-Module -ListAvailable PSWindowsUpdate)) {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
    Install-Module PSWindowsUpdate -Force -SkipPublisherCheck
}

Write-Log "Initial Setup Done. Rebooting."
Start-Sleep -Seconds 5
Restart-Computer -Force