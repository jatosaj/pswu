# Create local pswu script and set it to runonce
$ScriptContent = @'
Write-Output 'Starting Windows Update...'
Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot
Write-Output 'Windows Update has finished'
Add-Type -AssemblyName System.Speech
$synthesizer = New-Object System.Speech.Synthesis.SpeechSynthesizer
$text = "Windows update finished."
$synthesizer.Speak($text)
'@

$Destination = "C:\pswu-local.ps1"
Set-Content -Path $Destination -Value $ScriptContent
Set-ItemProperty -Path $Destination -Name Attributes -Value Hidden
# $runOnceKey = "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
# $entryName = "RunPSWU"
# New-ItemProperty -Path $runOnceKey -Name $entryName -Value "powershell.exe -ExecutionPolicy Bypass -File `"$Destination`""
$RunOnceKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
$Command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$Destination`""
New-ItemProperty -Path $RunOnceKey -Name "PSWU_RunAfterReboot" -Value $Command -PropertyType String -Force
Write-Output "Script scheduled to run after reboot.`n"

# # Check if the script is on drive C: and copy if absent
# If (!(Test-Path $Destination)) {
#   Copy-Item -Path $ScriptPath -Destination $Destination -Force
#   Write-Output "Script has been successfully copied to $Destination"
# }

# Set monitor timeout to always on
PowerCFG -Change -Monitor-Timeout-AC 0
Write-Output "Screen timeout is OFF"

# Check if the NuGet is installed
# Define the file paths
$filePath1 = "C:\Program Files\PackageManagement\ProviderAssemblies\nuget"
$filePath2 = "C:\Users\User\AppData\Local\PackageManagement\ProviderAssemblies\nuget"
# Check if the file exists in both locations
if ((Test-Path $filePath1) -or (Test-Path $filePath2)) {
    Write-Output "NuGet is installed."
} else {
    Write-Output "NuGet is not installed or is outdated. Installing..."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
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

# Start PSWindowsUpdate
Write-Output "Starting Windows Update..."
Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot
Write-Output "Windows Update has finished"