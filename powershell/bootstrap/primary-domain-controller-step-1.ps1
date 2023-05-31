#
#  Copyright 2018 Google Inc.
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

Function New-RandomString {
	Param(
		[int] $Length = 10,
		[char[]] $AllowedChars = $Null
	)
	If ($AllowedChars -eq $Null) {
		(,(33,126)) | % { For ($a=$_[0]; $a -le $_[1]; $a++) { $AllowedChars += ,[char][byte]$a } }
	}
	For ($i=1; $i -le $Length; $i++) {
		$Temp += ( $AllowedChars | Get-Random )
	}
	Return $Temp
}
Function New-RandomPassword() {
	Param(
		[int] $Length = 16,
		[char[]] $AllowedChars = $Null
	)
	Return New-RandomString -Length $Length -AllowedChars $AllowedChars | ConvertTo-SecureString -AsPlainText -Force
}
Function Unwrap-SecureString() {
	Param(
		[System.Security.SecureString] $SecureString
	)
	Return (New-Object -TypeName System.Net.NetworkCredential -ArgumentList '', $SecureString).Password
}

Function Get-GoogleMetadata() {
        Param (
        [Parameter(Mandatory=$True)][String] $Path
        )
        Try {
                Return Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/$Path
        }
        Catch {
                Return $Null
        }
}


Write-Host "Bootstrap script started..."


#Write-Host "Installing AD features in background..."
#Start-Job -ScriptBlock { Install-WindowsFeature -name AD-Domain-Services -IncludeManagementTools }
Write-Host "Installing AD features..."
Install-WindowsFeature -name AD-Domain-Services -IncludeManagementTools


#Write-Host "Removing external address in background..."
#Start-Job -ScriptBlock {
#	# windows should have activated before script is invoked, so now remove external address
#	$name = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/name
#	$zone = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/zone
#	gcloud compute instances delete-access-config $name --zone $zone
#}

If ("true" -like (Get-GoogleMetadata "instance/attributes/remove-address")) {
        Write-Host "Removing external address..."
        $name = Get-GoogleMetadata "instance/name"
        $zone = Get-GoogleMetadata "instance/zone"
        gcloud compute instances delete-access-config $name --zone $zone
}


Write-Host "Configuring network..."
# reconfigure dhcp address as static to avoid warnings during dcpromo
$IpAddr = Get-NetIPAddress -InterfaceAlias Ethernet -AddressFamily IPv4
$IpConf = Get-NetIPConfiguration -InterfaceAlias Ethernet
Set-NetIPInterface `
	-InterfaceAlias Ethernet `
	-Dhcp Disabled
New-NetIPAddress `
	-InterfaceAlias Ethernet `
	-IPAddress $IpAddr.IPAddress `
	-AddressFamily IPv4 `
	-PrefixLength $IpAddr.PrefixLength `
	-DefaultGateway $IpConf.IPv4DefaultGateway.NextHop

# set dns to google cloud default, will be set to loopback once dns feature is installed
Set-DnsClientServerAddress -InterfaceAlias Ethernet -ServerAddresses $IpConf.IPv4DefaultGateway.NextHop

# above can cause network blip, so wait until metadata server is responsive
$HaveMetadata = $False
While( ! $HaveMetadata ) { Try {
	Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/ 1>$Null 2>&1
	$HaveMetadata = $True
} Catch {
	Write-Host "Waiting on metadata..."
	Start-Sleep 5
} }
Write-Host "Contacted metadata server. Proceeding..."


Write-Host "Fetching metadata parameters..."
$Domain = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/attributes/domain-name
$NetBiosName = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/attributes/netbios-name
$KmsKey = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/attributes/kms-key
$GcsPrefix = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/attributes/gcs-prefix
$Region = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/attributes/region
$KmsRegion = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/attributes/keyring-region
$Keyring = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/attributes/keyring
#$RuntimeConfig = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/attributes/runtime-config

Write-Host "KMS Key has been fetched"

Write-Host "Configuring admin credentials..."
$SafeModeAdminPassword = New-RandomPassword
$LocalAdminPassword = New-RandomPassword

Set-LocalUser Administrator -Password $LocalAdminPassword
Enable-LocalUser Administrator

Write-Host "Saving encrypted credentials in GCS..."
If ($GcsPrefix.EndsWith("/")) {
  $GcsPrefix = $GcsPrefix -Replace ".$"
}
$TempFile = New-TemporaryFile

Unwrap-SecureString $LocalAdminPassword | gcloud kms encrypt --key $KmsKey --plaintext-file - --ciphertext-file $TempFile.FullName --location $KmsRegion  --keyring $Keyring
gsutil cp $TempFile.FullName "$GcsPrefix/output/domain-admin-password.bin"

Unwrap-SecureString $SafeModeAdminPassword | gcloud kms encrypt --key $KmsKey --plaintext-file - --ciphertext-file $TempFile.FullName --location $KmsRegion --keyring $Keyring
gsutil cp $TempFile.FullName "$GcsPrefix/output/dsrm-admin-password.bin"

Remove-Item $TempFile.FullName -Force

Write-Host "Waiting for background jobs..."
Get-Job | Wait-Job


Write-Host "Creating AD forest..."

$Params = @{
DomainName = $Domain
DomainNetbiosName = $NetBiosName
InstallDNS = $True
NoRebootOnCompletion = $True
SafeModeAdministratorPassword = $SafeModeAdminPassword
Force = $True
}
Install-ADDSForest @Params


Write-Host "Configuring startup metadata..."
$name = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/name
$zone = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/zone
gcloud compute instances add-metadata "$name" --zone $zone --metadata windows-startup-script-url="$GcsPrefix/powershell/bootstrap/primary-domain-controller-step-2.ps1"


Write-Host "Restarting computer after step 1 ..."

Restart-Computer
