# --- CONFIGURATION ---
$TotalReboots = 1                          
$DeviceInstanceID = ""                     
$DriverINF = ""                   
$Destination = "$env:ProgramData\PSWU\pswu.ps1" 
$LogPath = "$env:ProgramData\PSWU\pswu_log.txt" 
$StoreInstall = "9WZDNCRFJ4MV"             

# --- INITIAL LOGGING FUNCTION ---
function Write-Log {
    param([string]$Msg, [string]$Level = "INFO")
    $Stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$Stamp] [$Level] $Msg" | Out-File -FilePath $LogPath -Append
}

# Clear/Start Log with a Header
"------------------------------------------------" | Out-File -FilePath $LogPath -Append
Write-Log "NEW DEPLOYMENT INITIALIZED"
Write-Log "Targeting Store App: $StoreInstall"

# --- PERSISTENT SCRIPT CONTENT ---
$ScriptContent = @"
`$LogFile = '$LogPath'
`$RegPath = 'HKLM:\SOFTWARE\PSWU'

function Write-Log {
    param([string]`$Msg, [string]`$Level = "INFO")
    `$Stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[`$Stamp] [`$Level] `$Msg" | Out-File -FilePath `$LogFile -Append
}

# Visual separator in the log for each reboot
"--- REBOOT CYCLE STARTED ---" | Out-File -FilePath `$LogFile -Append

try {
    `$CurrentCount = [int](Get-ItemProperty -Path `$RegPath -Name 'RebootCount' -ErrorAction Stop).RebootCount
} catch {
    `$CurrentCount = 1
}

Write-Log "Cycles remaining: `$CurrentCount"

if (`$CurrentCount -gt 1) {
    # INTERMEDIATE PASS
    `$NewCount = `$CurrentCount - 1
    Set-ItemProperty -Path `$RegPath -Name 'RebootCount' -Value `$NewCount
    `$RunOnceKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
    `$Command = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$Destination"'
    New-ItemProperty -Path `$RunOnceKey -Name 'PSWU_RunAfterReboot' -Value `$Command -PropertyType String -Force
    Write-Log "Intermediate pass complete. Prepared next RunOnce."
} else {
    # FINAL PASS: STORE & CLEANUP
    Write-Log "Entering Final Pass sequence."

    try {
        Write-Log "Checking for 'store' command..."
        if (Get-Command "store" -ErrorAction SilentlyContinue) {
            Write-Log "Executing: store install $StoreInstall"
            # Capture all output (Success and Error) to a variable then log it
            `$StoreResult = store install $StoreInstall *>&1 | Out-String
            Write-Log "STORE OUTPUT:`n`n`$StoreResult" -Level "OUTPUT"
        } else {
            Write-Log "Searching system for store.exe..."
            `$ManualPath = (Get-ChildItem -Path "C:\Windows\System32", "C:\Windows\SysWOW64" -Filter "store.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
            if (`$ManualPath) {
                Write-Log "Executing via path: `$ManualPath"
                `$StoreResult = & "`$ManualPath" install $StoreInstall *>&1 | Out-String
                Write-Log "STORE OUTPUT:`n`n`$StoreResult" -Level "OUTPUT"
            } else {
                Write-Log "Store utility not found on disk." -Level "ERROR"
            }
        }
    } catch {
        Write-Log "Exception during Store task: `$($_.Exception.Message)" -Level "ERROR"
    }

    # Cleanup
    if ("$DeviceInstanceID") { 
        Write-Log "Removing Device: $DeviceInstanceID"
        pnputil /remove-device "$DeviceInstanceID" 2>&1 | Out-File -FilePath `$LogFile -Append
    }
    if ("$DriverINF") { 
        Write-Log "Removing Driver: $DriverINF"
        pnputil /delete-driver $DriverINF /uninstall /force 2>&1 | Out-File -FilePath `$LogFile -Append
    }
    
    Remove-Item -Path `$RegPath -Recurse -ErrorAction SilentlyContinue
    Write-Log "Cleanup complete. Registry tracking removed."
}

# --- WINDOWS UPDATE BLOCK ---
Write-Log "Starting Windows Update check..."
try {
    Import-Module PSWindowsUpdate
    # Capture Update results directly into log
    Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot -ErrorAction Stop *>&1 | Out-File -FilePath `$LogFile -Append
} catch {
    Write-Log "Update failed: `$($_.Exception.Message)" -Level "ERROR"
    if (`$_.Exception.Message -match "expected range") {
        Write-Log "Repairing WU Components..."
        Reset-WUComponents -Confirm:`$false *>&1 | Out-File -FilePath `$LogFile -Append
    }
}

if (`$CurrentCount -gt 1) {
    Write-Log "Rebooting for next pass..."
    Start-Sleep -Seconds 5
    Restart-Computer -Force
} else {
    Write-Log "SEQUENCE FINISHED SUCCESSFULLY."
    Add-Type -AssemblyName System.Speech
    (New-Object System.Speech.Synthesis.SpeechSynthesizer).Speak('Sequence finished.')
}
"@

# --- INITIAL OOBE SETUP ---
Write-Log "Creating persistent script at $Destination"
Set-Content -Path $Destination -Value $ScriptContent
Set-ItemProperty -Path $Destination -Name Attributes -Value Hidden

Write-Log "Configuring Registry tracking..."
$RegPath = "HKLM:\SOFTWARE\PSWU"
if (!(Test-Path $RegPath)) { New-Item -Path $RegPath -Force | Out-Null }
Set-ItemProperty -Path $RegPath -Name "RebootCount" -Value $TotalReboots

Write-Log "Setting RunOnce key..."
$RunOnceKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
$Command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$Destination`""
New-ItemProperty -Path $RunOnceKey -Name "PSWU_RunAfterReboot" -Value $Command -PropertyType String -Force

Write-Log "Disabling monitor sleep..."
PowerCFG -Change -Monitor-Timeout-AC 0

if (!(Get-Module -ListAvailable PSWindowsUpdate)) {
    Write-Log "Downloading PSWindowsUpdate Module..."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
    Install-Module PSWindowsUpdate -Force -SkipPublisherCheck
}

Write-Log "Initial OOBE pass finished. Triggering first reboot."
Start-Sleep -Seconds 5
Restart-Computer -Force