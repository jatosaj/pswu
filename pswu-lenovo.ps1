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

Write-Log "Initializing pswu-lenovo bootstrap script."

# --- PERSISTENT SCRIPT (The part that survives reboots) ---
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

Write-Log "Current Cycle: `$CurrentCount"

if (`$CurrentCount -gt 1) {
    # --- INTERMEDIATE PASS LOGIC ---
    `$NewCount = `$CurrentCount - 1
    Set-ItemProperty -Path `$RegPath -Name 'RebootCount' -Value `$NewCount
    `$RunOnceKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
    `$Command = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$Destination"'
    New-ItemProperty -Path `$RunOnceKey -Name 'PSWU_RunAfterReboot' -Value `$Command -PropertyType String -Force
} else {
    # --- FINAL PASS LOGIC: STORE INSTALL & CLEANUP ---
    Write-Log "Final pass detected. Attempting Store Install."

    try {
        # Check if the 'store' command is recognized in the current PATH
        if (Get-Command "store" -ErrorAction SilentlyContinue) {
            Write-Log "Calling 'store' command directly..."
            store install $StoreInstall
        } else {
            # If not in PATH, try to find the actual .exe in system folders
            Write-Log "'store' command not in PATH. Searching for executable..."
            `$ManualPath = (Get-ChildItem -Path "C:\Windows\System32", "C:\Windows\SysWOW64" -Filter "store.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
            
            if (`$ManualPath) {
                Write-Log "Found store.exe at: `$ManualPath"
                & "`$ManualPath" install $StoreInstall
            } else {
                Write-Log "CRITICAL: Could not find the 'store' utility on this system."
            }
        }
    } catch {
        Write-Log "An error occurred during Store installation: `$($_.Exception.Message)"
    }

    # Driver/Device Cleanup
    if ("$DeviceInstanceID") { 
        Write-Log "Removing device: $DeviceInstanceID"
        pnputil /remove-device "$DeviceInstanceID" | Out-Null 
    }
    if ("$DriverINF") { 
        Write-Log "Deleting driver: $DriverINF"
        pnputil /delete-driver $DriverINF /uninstall /force | Out-Null 
    }
    
    Remove-Item -Path `$RegPath -Recurse -ErrorAction SilentlyContinue
}

# --- WINDOWS UPDATE BLOCK (Runs every pass) ---
try {
    Import-Module PSWindowsUpdate
    Write-Log "Checking for Windows Updates..."
    Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot -ErrorAction Stop
} catch {
    `$ErrMsg = `$_.Exception.Message
    Write-Log "UPDATE ERROR: `$ErrMsg"
    if (`$ErrMsg -match "expected range") {
        Write-Log "Triggering WU database repair (Reset-WUComponents)..."
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
    (New-Object System.Speech.Synthesis.SpeechSynthesizer).Speak('Deployment Finished')
}
"@

# --- INITIAL SETUP (OOBE Phase) ---
Set-Content -Path $Destination -Value $ScriptContent
Set-ItemProperty -Path $Destination -Name Attributes -Value Hidden

$RegPath = "HKLM:\SOFTWARE\PSWU"
if (!(Test-Path $RegPath)) { New-Item -Path $RegPath -Force | Out-Null }
Set-ItemProperty -Path $RegPath -Name "RebootCount" -Value $TotalReboots

$RunOnceKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
$Command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$Destination`""
New-ItemProperty -Path $RunOnceKey -Name "PSWU_RunAfterReboot" -Value $Command -PropertyType String -Force

# Prevent monitor from turning off during long update passes
PowerCFG -Change -Monitor-Timeout-AC 0

# Set up the Windows Update Module
if (!(Get-Module -ListAvailable PSWindowsUpdate)) {
    Write-Log "Installing PSWindowsUpdate Module..."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
    Install-Module PSWindowsUpdate -Force -SkipPublisherCheck
}

Write-Log "Initial OOBE setup complete. Triggering first reboot."
Start-Sleep -Seconds 60
Restart-Computer -Force