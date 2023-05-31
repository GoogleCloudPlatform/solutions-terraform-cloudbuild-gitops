#
#  Copyright 2019 Google Inc.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#



$tempdir = "c:\temp\"
$tempdir = $tempdir.tostring()
$appToMatch = 'Stackdriver*'
$msiFile = "C:\Windows\system32\msiexec.exe"

$LOG='c:\temp\install.log'

#function to write debugging info to the console
Function Write-SerialPort ([string] $message) {
    $port = new-Object System.IO.Ports.SerialPort COM1,9600,None,8,one
    $port.open()
    $port.WriteLine($message)
    $port.Close()
}

function Get-InstalledApps
{
    if ([IntPtr]::Size -eq 4) {
        $regpath = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    }
    else {
        $regpath = @(
            'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
            'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )
    }
    Get-ItemProperty $regpath | .{process{if($_.DisplayName -and $_.UninstallString) { $_ } }} | Select DisplayName, Publisher, InstallDate, DisplayVersion, UninstallString |Sort DisplayName
}

Write-SerialPort "Environment passed in was: ${environment}"

#is stackdriver installed
$result = Get-InstalledApps | where {$_.DisplayName -like $appToMatch}

#if we are not admin
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
  # Relaunch as an elevated process:
  Write-SerialPort "Elevating"
  Start-Process powershell.exe "-File",('"{0}"' -f $MyInvocation.MyCommand.Path) -Verb RunAs
  exit
}

Write-SerialPort "Prefix: ${environment} Name: ${projectname} comes from the project itself"
Write-SerialPort "Elevated"

Write-Host "Bootstrap script started..."


Write-Host "Getting network config..."
# reconfigure dhcp address as static to avoid warnings during dcpromo
$IpAddr = Get-NetIPAddress -InterfaceAlias Ethernet
$IpConf = Get-NetIPConfiguration -InterfaceAlias Ethernet

Write-SerialPort "Fetching metadata parameters..."
$Domain = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/attributes/domain-name
#$NetBiosName = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/attributes/netbios-name
$KmsKey = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/attributes/kms-key
$KmsRegion = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/attributes/keyring-region
$GcsPrefix = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/attributes/gcs-prefix

Write-SerialPort $Domain, $IpAddr, $GcsPrefix

$tempPath = "c:\temp\"

Write-Host "temp dir: $tempPath"

if((Test-Path $tempPath) -eq 0){
   New-Item -ItemType directory -Path c:\temp\
   Write-Host "created c:\temp"
}

cd C:\temp\

$tempSDPath = "c:\temp\StackdriverMonitoring-GCM-46.exe"

#get stackdriver
if((Test-Path $tempSDPath) -eq 0){
    Write-Host("Downloading stackdriver agent")
    invoke-webrequest https://repo.stackdriver.com/windows/StackdriverMonitoring-GCM-46.exe -OutFile $tempSDPath;
}else{
    Write-Host("Stackdriver Agent already downloaded")
}

Write-SerialPort("Get installed apps")

$appToMatch = "StackdriverAgent"

$result = Get-Process | where {$_.ProcessName -like $appToMatch}

# Now running elevated so launch the script:
If ($result -eq $null) {
    Write-Host "Running the Stackdriver install"
    .\StackdriverMonitoring-GCM-46.exe /S
    #msiexec.exe /qn /norestart /i $tempdir\$puppetInstall PUPPET_MASTER_SERVER=$PROJECT_PREFIX-puppet-p.c.$PROJECT_NAME.internal PUPPET_AGENT_ENVIRONMENT=$PUPPET_AGENT_ENVIRONMENT  /l* $LOG
}else{
    Write-Host "Stackdriver is already installed"
}

Write-Host "Configuring windows-startup-script-url"
$name = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/name
$zone = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/zone
$function = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/attributes/function

if ($function -eq "pdc"){
  Write-Host "Setting windows-startup-script-url in metadata to $GcsPrefix/powershell/bootstrap/primary-domain-controller-step-1.ps1"
  gcloud compute instances add-metadata "$name" --zone $zone --metadata windows-startup-script-url="$GcsPrefix/powershell/bootstrap/primary-domain-controller-step-1.ps1"
}elseif ($function -eq "sql"){
  Write-Host "Setting windows-startup-script-url in metadata to $GcsPrefix/powershell/bootstrap/install-sql-server-principal-step-1.ps1"
  gcloud compute instances add-metadata "$name" --zone $zone --metadata windows-startup-script-url="$GcsPrefix/powershell/bootstrap/domain-member.ps1"
}

Write-Host "Removing windows-startup-script-ps1 from metadata ..."
gcloud compute instances remove-metadata "$name" --zone $zone --keys="windows-startup-script-ps1"

Write-Host "Restarting computer after winstartup ..."
Restart-Computer
