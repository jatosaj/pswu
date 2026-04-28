# --- CONFIGURATION VARIABLES ---
$TotalReboots = 1
$DeviceInstanceID = ""
$DriverINF = "oem93.inf"
$Destination = "$env:ProgramData\pswu.ps1"
$LogPath = "$env:ProgramData\pswu_log.txt"
$StoreInstall = "9WZDNCRFJ4MV"

# --- LOGGING FUNCTION ---
function Write-Log {
    param($Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$Timestamp] $Message" | Out-File -FilePath $LogPath -Append
    Write-Output $Message
}

# 1. INITIAL SETTLE TIME
Write-Log "Initializing. Waiting 30s for Windows 11 Store services to initialize..."
Start-Sleep -Seconds 30

# --- CREATE THE PERSISTENT SCRIPT (The Here-String) ---
$ScriptContent = @"
`$RegPath = 'HKLM:\SOFTWARE\PSWU'
`$LogFile = '$LogPath'
function Write-Log {
    param(`$Message)
    `$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[`$Timestamp] `$Message" | Out-File -FilePath `$LogFile -Append
}
# ... (Self-Healing logic from previous version) ...
"@

# --- INITIAL SETUP ---
Write-Log "Preparing persistent environment..."
Set-Content -Path $Destination -Value $ScriptContent
$RegPath = "HKLM:\SOFTWARE\PSWU"
if (!(Test-Path $RegPath)) { New-Item -Path $RegPath -Force | Out-Null }
Set-ItemProperty -Path $RegPath -Name "RebootCount" -Value $TotalReboots

$RunOnceKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
$Command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$Destination`""
New-ItemProperty -Path $RunOnceKey -Name "PSWU_RunAfterReboot" -Value $Command -PropertyType String -Force

# --- THE FIX: ROBUST STORE INSTALL ---
Write-Log "Locating 'store' CLI path..."
# We search for the actual exe in case the alias isn't loaded yet
$StorePath = (Get-Command "store" -ErrorAction SilentlyContinue).Source
if (-not $StorePath) { $StorePath = "store" } # Fallback to alias if search fails

Write-Log "Targeting Store ID: $StoreInstall using path: $StorePath"

$Success = $false
$Retry = 0
while (-not $Success -and $Retry -lt 3) {
    try {
        Write-Log "Attempting install (Try $($Retry + 1))..."
        # & calls the path directly, ensuring it runs even if the path isn't in $env:PATH
        & $StorePath install $StoreInstall --accept-package-agreements
        
        if ($LASTEXITCODE -eq 0) {
            $Success = $true
            Write-Log "Store installation signaled success."
        } else {
            throw "Store exited with code $LASTEXITCODE"
        }
    } catch {
        $Retry++
        Write-Log "Store Install busy or failed: $($_.Exception.Message). Retrying in 20s..."
        Start-Sleep -Seconds 20
    }
}

# --- WINDOWS UPDATES ---
if (!(Get-Module -ListAvailable PSWindowsUpdate)) {
    Write-Log "Installing PSWindowsUpdate Module..."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
    Install-Module PSWindowsUpdate -Force -SkipPublisherCheck
}

Write-Log "Starting Update Pass..."
Import-Module PSWindowsUpdate
Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot

# Manual reboot to trigger the loop
Write-Log "Cycle 0 complete. Rebooting."
Start-Sleep -Seconds 5
Restart-Computer -Force