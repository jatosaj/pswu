# --- CONFIGURATION ---
$TotalReboots = 3.            # Set the ammount of the reboots required.
$DeviceInstanceID = "foo-bar" # Where to find it: In Device Manager, right-click the device > Properties > Details tab > Select Device instance path from the dropdown.
$DriverINF = "foo-bar"        # Where to find it: In Device Manager, right-click the device > Properties > Details tab > Select Inf name from the dropdown.
$Destination = "%ProgramFiles%\PowerShell"

# --- CREATE THE PERSISTENT SCRIPT ---
$ScriptContent = @"
`$RegPath = 'HKLM:\SOFTWARE\PSWU'
`$CurrentCount = 0

try {
    `$CurrentCount = [int](Get-ItemProperty -Path `$RegPath -Name 'RebootCount' -ErrorAction Stop).RebootCount
} catch {
    `$CurrentCount = 1
}

if (`$CurrentCount -gt 1) {
    # Still in the loop: Decrement counter and re-arm RunOnce
    `$NewCount = `$CurrentCount - 1
    Set-ItemProperty -Path `$RegPath -Name 'RebootCount' -Value `$NewCount
    
    `$RunOnceKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
    `$Command = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$Destination"'
    New-ItemProperty -Path `$RunOnceKey -Name 'PSWU_RunAfterReboot' -Value `$Command -PropertyType String -Force
    
    Write-Output "Cycle `$CurrentCount of $TotalReboots. Updates starting..."
} else {
    # LAST PASS: Perform Cleanup and final tasks
    Write-Output "Final pass detected. Running device and driver cleanup..."
    
    # Remove Device Instance
    pnputil /remove-device "$DeviceInstanceID"
    
    # Delete Driver Package
    pnputil /delete-driver $DriverINF /uninstall /force
    
    Remove-Item -Path `$RegPath -Recurse -ErrorAction SilentlyContinue
}

# Run Windows Update
Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot

# Handle reboot logic if Install-WindowsUpdate doesn't trigger one
if (`$CurrentCount -gt 1) {
    Write-Output "Cycle complete. Rebooting for next pass..."
    Start-Sleep -Seconds 5
    Restart-Computer -Force
} else {
    Write-Output "Sequence Complete."
    Add-Type -AssemblyName System.Speech
    (New-Object System.Speech.Synthesis.SpeechSynthesizer).Speak('All cycles and cleanup finished')
}
"@

# --- INITIAL SETUP ---
Set-Content -Path $Destination -Value $ScriptContent
Set-ItemProperty -Path $Destination -Name Attributes -Value Hidden

$RegPath = "HKLM:\SOFTWARE\PSWU"
if (!(Test-Path $RegPath)) { New-Item -Path $RegPath -Force | Out-Null }
Set-ItemProperty -Path $RegPath -Name "RebootCount" -Value $TotalReboots

$RunOnceKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
$Command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$Destination`""
New-ItemProperty -Path $RunOnceKey -Name "PSWU_RunAfterReboot" -Value $Command -PropertyType String -Force

# Prerequisites & First Run
PowerCFG -Change -Monitor-Timeout-AC 0

if (!(Get-Module -ListAvailable PSWindowsUpdate)) {
    Write-Output "Installing PSWindowsUpdate module..."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
    Install-Module PSWindowsUpdate -Force
}

Import-Module PSWindowsUpdate
Write-Output "Starting first cycle..."
Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot
Restart-Computer -Force