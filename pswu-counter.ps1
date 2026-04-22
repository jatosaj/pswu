# Define how many times the machine should reboot and resume the script
$TotalReboots = 3

# Create local pswu script and set it to handle the reboot loop
$ScriptContent = @'
$RegPath = "HKLM:\SOFTWARE\PSWU"
$CurrentCount = 0

# Read the current reboot counter from the registry
try {
    $CurrentCount = [int](Get-ItemProperty -Path $RegPath -Name "RebootCount" -ErrorAction Stop).RebootCount
} catch {
    $CurrentCount = 1 # Fallback if registry key is missing
}

# If we have more loops to go, decrement the counter and re-arm RunOnce
if ($CurrentCount -gt 1) {
    $NewCount = $CurrentCount - 1
    Set-ItemProperty -Path $RegPath -Name "RebootCount" -Value $NewCount

    $RunOnceKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
    $Command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"C:\pswu.ps1`""
    New-ItemProperty -Path $RunOnceKey -Name "PSWU_RunAfterReboot" -Value $Command -PropertyType String -Force
} else {
    # If this is the final run, clean up the registry key
    Remove-Item -Path $RegPath -Recurse -ErrorAction SilentlyContinue
}

Write-Output "Starting Windows Update... (Cycles remaining: $($CurrentCount - 1))"

# -AutoReboot may trigger a restart right here. 
# Because we already re-armed RunOnce above, the loop is safe.
Install-WindowsUpdate -MicrosoftUpdate -NotKBArticleID KB5063878 -AcceptAll -AutoReboot

# If execution reaches this point, -AutoReboot didn't trigger (no updates required a restart)
if ($CurrentCount -gt 1) {
    Write-Output "Updates complete for this cycle. Forcing reboot for the next cycle..."
    Start-Sleep -Seconds 5
    Restart-Computer -Force
} else {
    Write-Output 'Windows Update sequence completely finished.'
    Add-Type -AssemblyName System.Speech
    $synthesizer = New-Object System.Speech.Synthesis.SpeechSynthesizer
    $text = "Windows update has finished!"
    $synthesizer.Speak($text)
    Start-Sleep -Seconds 10
}
'@

# Define where to store script on target machine
$Destination = "C:\pswu.ps1"

# Create the file
Set-Content -Path $Destination -Value $ScriptContent

# Change file to hidden
Set-ItemProperty -Path $Destination -Name Attributes -Value Hidden

# Set up the initial Registry Counter for the loop
$RegPath = "HKLM:\SOFTWARE\PSWU"
New-Item -Path $RegPath -Force | Out-Null
Set-ItemProperty -Path $RegPath -Name "RebootCount" -Value $TotalReboots

# Arm the first RunOnce execution
$RunOnceKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
$Command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$Destination`""
New-ItemProperty -Path $RunOnceKey -Name "PSWU_RunAfterReboot" -Value $Command -PropertyType String -Force
Write-Output "Script scheduled to run after reboot. Total loops set to: $TotalReboots`n"

# Set monitor timeout to always on on AC
PowerCFG -Change -Monitor-Timeout-AC 0
Write-Output "Screen timeout is OFF"

# Check if the NuGet is installed
$filePath1 = "C:\Program Files\PackageManagement\ProviderAssemblies\nuget"
$filePath2 = "$env:LOCALAPPDATA\PackageManagement\ProviderAssemblies\nuget"
if ((Test-Path $filePath1) -or (Test-Path $filePath2)) {
    Write-Output "NuGet is installed."
} else {
    Write-Output "NuGet is not installed or is outdated. Installing..."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
}

# Check if PSWindowsUpdate is installed
$filePath3 = "C:\Program Files\WindowsPowerShell\Modules\PSWindowsUpdate\"
if (Test-Path $filePath3) {
    Write-Output "PSWindowsUpdate is installed."
} else {
    Write-Output "PSWindowsUpdate is not installed or is outdated. Installing..."
    Install-Module PSWindowsUpdate -Force
    Write-Output "PSWindowsUpdate installed"
}

# Import PSWindowsUpdate module
Import-Module PSWindowsUpdate
Write-Output "PSWindowsUpdate module imported"

Write-Output 'If you encounter "Value does not fall within the expected range" error - run Reset-WUComponents and restart the script' 

# Start Initial Windows Update
Write-Output "Starting Initial Windows Update..."
Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot
Write-Output "Initial Windows Update has finished. Rebooting..."
Start-Sleep -Seconds 10
Restart-Computer