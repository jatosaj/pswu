# Create local pswu script and set it to runonce
$ScriptContent = @'
Write-Output 'Starting Windows Update...'
Install-WindowsUpdate -MicrosoftUpdate -NotKBArticleID KB5063878 -AcceptAll -AutoReboot
Write-Output 'Windows Update has finished.'
Add-Type -AssemblyName System.Speech
$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
$polishVoice = $synth.GetInstalledVoices() | Where-Object { $_.VoiceInfo.Culture.Name -eq "pl-PL" } | Select-Object -First 1
$synth.SelectVoice($polishVoice.VoiceInfo.Name)
$text = "Aktualizacja gotowa"
$synth.Speak($text)
Set-ExecutionPolicy -ExecutionPolicy Default
Start-Sleep -Seconds 10
'@

#Install polish language
#Install-Language -Language pl-PL

# Define where to store script on target machine
$Destination = "C:\pswu.ps1"

# Create the file to run once
Set-Content -Path $Destination -Value $ScriptContent

# Change file to hidden
Set-ItemProperty -Path $Destination -Name Attributes -Value Hidden

$RunOnceKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
$Command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$Destination`""
New-ItemProperty -Path $RunOnceKey -Name "PSWU_RunAfterReboot" -Value $Command -PropertyType String -Force
Write-Output "Script scheduled to run after reboot.`n"

# Set monitor timeout to always on on AC
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
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force |Out-Null
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
Write-Output "Windows Update has finished. Rebooting..."
Start-Sleep -Seconds 10
Restart-Computer