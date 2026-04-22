$TotalReboots = 3
$Destination = "C:\pswu.ps1"
$DeviceName = "ThinkPad P15 / P17 Gen 2 Embedded controller Firmware 1.09"
$DriverInf = "oem93.inf"

$ScriptContent = @"
`$RegPath = 'HKLM:\SOFTWARE\PSWU'
`$CurrentCount = 0

try {
    `$CurrentCount = [int](Get-ItemProperty -Path `$RegPath -Name 'RebootCount' -ErrorAction Stop).RebootCount
} catch {
    `$CurrentCount = 1
}

if (`$CurrentCount -gt 1) {
    `$NewCount = `$CurrentCount - 1
    Set-ItemProperty -Path `$RegPath -Name 'RebootCount' -Value `$NewCount
    `$RunOnceKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
    `$Command = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$Destination"'
    New-ItemProperty -Path `$RunOnceKey -Name 'PSWU_RunAfterReboot' -Value `$Command -PropertyType String -Force
} else {
    Remove-Item -Path `$RegPath -Recurse -ErrorAction SilentlyContinue
}

# --- Device & Driver Cleanup ---
Write-Output "Removing: $DeviceName"
Get-PnpDevice -FriendlyName "$DeviceName" -ErrorAction SilentlyContinue | Remove-PnpDevice -Confirm:`$false

Write-Output "Deleting: $DriverInf"
pnputil /delete-driver $DriverInf /uninstall /force | Out-Null

# --- Windows Update ---
Write-Output "Cycles remaining: `$(`$CurrentCount - 1)"
Install-WindowsUpdate -MicrosoftUpdate -NotKBArticleID KB5063878 -AcceptAll -AutoReboot

if (`$CurrentCount -gt 1) {
    Start-Sleep -Seconds 5
    Restart-Computer -Force
} else {
    Add-Type -AssemblyName System.Speech
    (New-Object System.Speech.Synthesis.SpeechSynthesizer).Speak('Sequence finished')
}
"@

# Setup environment
Set-Content -Path $Destination -Value $ScriptContent
Set-ItemProperty -Path $Destination -Name Attributes -Value Hidden

$RegPath = "HKLM:\SOFTWARE\PSWU"
if (!(Test-Path $RegPath)) { New-Item -Path $RegPath -Force | Out-Null }
Set-ItemProperty -Path $RegPath -Name "RebootCount" -Value $TotalReboots

$RunOnceKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
$Command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$Destination`""
New-ItemProperty -Path $RunOnceKey -Name "PSWU_RunAfterReboot" -Value $Command -PropertyType String -Force

# Prerequisites & Initial Run
PowerCFG -Change -Monitor-Timeout-AC 0

if (!(Get-Module -ListAvailable PSWindowsUpdate)) {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
    Install-Module PSWindowsUpdate -Force
}

Import-Module PSWindowsUpdate
Write-Output "Starting initial cycle..."
Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot
Restart-Computer -Force