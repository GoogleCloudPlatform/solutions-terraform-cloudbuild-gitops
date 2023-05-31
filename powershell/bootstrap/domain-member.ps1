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

Function Unwrap-SecureString() {
	Param(
		[System.Security.SecureString] $SecureString
	)
	Return (New-Object -TypeName System.Net.NetworkCredential -ArgumentList '', $SecureString).Password
}

Function Set-RuntimeConfigVariable {
        Param(
		[Parameter(Mandatory=$True)][String] $ConfigPath,
		[Parameter(Mandatory=$True)][String] $Variable,
		[Parameter(Mandatory=$True)][String] $Text
        )

	$Auth = $(gcloud auth print-access-token)

	$Path = "$ConfigPath/variables"
	$Url = "https://runtimeconfig.googleapis.com/v1beta1/$Path"

	$Json = (@{
	name = "$Path/$Variable"
	text = $Text
	} | ConvertTo-Json)

	$Headers = @{
	Authorization = "Bearer " + $Auth
	}

	$Params = @{
	Method = "POST"
	Headers = $Headers
	ContentType = "application/json"
	Uri = $Url
	Body = $Json
	}

	Try {
		Return Invoke-RestMethod @Params
	}
	Catch {
	        $Reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        	$ErrResp = $Reader.ReadToEnd() | ConvertFrom-Json
        	$Reader.Close()
		Return $ErrResp
	}

}

Function Get-RuntimeConfigWaiter {
	Param(
		[Parameter(Mandatory=$True)][String] $ConfigPath,
		[Parameter(Mandatory=$True)][String] $Waiter
	)

	$Auth = $(gcloud auth print-access-token)

	$Url = "https://runtimeconfig.googleapis.com/v1beta1/$ConfigPath/waiters/$Waiter"
	$Headers = @{
	Authorization = "Bearer " + $Auth
	}
	$Params = @{
	Method = "GET"
	Headers = $Headers
	Uri = $Url
	}

	Return Invoke-RestMethod @Params
}

Function Wait-RuntimeConfigWaiter {
	Param(
		[Parameter(Mandatory=$True)][String] $ConfigPath,
		[Parameter(Mandatory=$True)][String] $Waiter,
		[int] $Sleep = 60
	)
	$RuntimeWaiter = $Null
	While (($RuntimeWaiter -eq $Null) -Or (-Not $RuntimeWaiter.done)) {
		$RuntimeWaiter = Get-RuntimeConfigWaiter -ConfigPath $ConfigPath -Waiter $Waiter
		If (-Not $RuntimeWaiter.done) {
			Write-Host "Waiting for [$ConfigPath/waiters/$Waiter]..."
			Sleep $Sleep
		}
	}
	Return $RuntimeWaiter
}

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

Function Create-RuntimeConfigWaiter {
	Param(
		[Parameter(Mandatory=$True)][String] $ConfigPath,
		[Parameter(Mandatory=$True)][String] $Waiter,
        [Parameter(Mandatory=$True)][String] $Timeout,
        [Parameter(Mandatory=$True)][String] $SuccessPath,
        [Parameter(Mandatory=$True)][Int] $SuccessCardinality,
        [Parameter(Mandatory=$False)][String] $FailurePath = "",
        [Parameter(Mandatory=$False)][Int] $FailureCardinality=0
	)

	$RuntimeWaiter = $Null

    Write-Host $ConfigPath/waiters/$Waiter

	$Auth = $(gcloud auth print-access-token)


    if($FailurePath.Length -eq 0){
        $Body = "{timeout: '" + $Timeout + "s', name: '$ConfigPath/waiters/$Waiter', success: { cardinality: { number: $SuccessCardinality, path: '$SuccessPath' }}}"
    }else{
        $Body = "{timeout: '" + $Timeout + "s', name: '$ConfigPath/waiters/$Waiter', `
            success: { cardinality: { number: $SuccessCardinality, path: '$SuccessPath' }}, `
            failure: { cardinality: { number: $FailureCardinality, path: '$FailurePath' }}}"
    }

	$Url = "https://runtimeconfig.googleapis.com/v1beta1/$ConfigPath/waiters"

    $Headers = @{
	    Authorization="Bearer " + $Auth
	}
	$Params = @{
	    Method = "POST"
	    Headers = $Headers
	    Uri = $Url
        Body=$Body
	}
    Write-Host "$Url"
   # Write-Host  "$Params"

	#Return Invoke-RestMethod $Params
    Return Invoke-RestMethod -Uri $Url -Headers $Headers -Method 'Post' -Body $Body  -ContentType "application/json"
	#Return $RuntimeWaiter
}

Function Delete-RuntimeConfigWaiter {
	Param(
		[Parameter(Mandatory=$True)][String] $ConfigPath,
		[Parameter(Mandatory=$True)][String] $Waiter
	)

	$RuntimeWaiter = $Null

    Write-Host $ConfigPath/waiters/$Waiter

	$Auth = $(gcloud auth print-access-token)

	$Url = "https://runtimeconfig.googleapis.com/v1beta1/$ConfigPath/waiters/$Waiter"

    $Headers = @{
	    Authorization="Bearer " + $Auth
	}

    Write-Host "$Url"

    Return Invoke-RestMethod -Uri $Url -Headers $Headers -Method 'Delete'
}

Function New-RandomPassword() {
	Param(
		[int] $Length = 16,
		[char[]] $AllowedChars = $Null
	)
	Return New-RandomString -Length $Length -AllowedChars $AllowedChars | ConvertTo-SecureString -AsPlainText -Force
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


$name = Get-GoogleMetadata "instance/name"
$zone = Get-GoogleMetadata "instance/zone"

If ("true" -like (Get-GoogleMetadata "instance/attributes/remove-address")) {
	Write-Host "Removing external address..."
	gcloud compute instances delete-access-config $name --zone $zone
}


Write-Host "Adding AD powershell tools..."
Add-WindowsFeature RSAT-AD-PowerShell

# the path to the runtime-config must be the full path ie. 
# "projects/{project-name}/configs/acme-runtime-config"
# the success path is what is in wait-on
# waiter name does not need to be passed in
$Waiter = $name + '_waiter'

$Deployment = Get-GoogleMetadata "instance/attributes/deployment-name"
$SuccessPath = Get-GoogleMetadata "instance/attributes/wait-on"
$ProjectId = Get-GoogleMetadata "/instance/attributes/project-id"
$RuntimeConfig = Get-GoogleMetadata "instance/attributes/runtime-config"
$FullRTConfigPath = "projects/$ProjectId/configs/$RuntimeConfig"

Write-Host "Runtime-config waiter is $Waiter"
Write-Host "Success path is $SuccessPath"
Write-Host "Full runtime-config path is: $FullRTConfigPath"

If ($SuccessPath) {
	Write-Host "Waiting for $SuccessPath..."
	Write-Host "Config $RuntimeConfig and waiter: $Waiter"

	$result = Create-RuntimeConfigWaiter $FullRTConfigPath `
		$Waiter `
		1800 `
		$SuccessPath `
		1

	Write-Host $result

	Wait-RuntimeConfigWaiter -ConfigPath $FullRTConfigPath -Waiter $Waiter
}


Write-Host "Configuring network..."
$DomainControllerAddresses = Get-GoogleMetadata "instance/attributes/domain-controller-address"
# set dns to domain controller
Set-DnsClientServerAddress -InterfaceAlias Ethernet -ServerAddresses $DomainControllerAddresses

Write-Host "Configuring local admin..."
# startup script runs as local system which cannot join domain
# so do the join as local administrator using random password
$LocalAdminPassword = New-RandomPassword
Set-LocalUser Administrator -Password $LocalAdminPassword
Enable-LocalUser Administrator

$LocalAdminCredentials = New-Object `
        -TypeName System.Management.Automation.PSCredential `
        -ArgumentList "\Administrator",$LocalAdminPassword
Invoke-Command -Credential $LocalAdminCredentials -ComputerName . -ScriptBlock {

	Write-Host "Getting job metadata..."
	$Domain = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/attributes/domain-name
	$NetBiosName = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/attributes/netbios-name
	$KmsKey = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/attributes/kms-key
	$KmsRegion = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/attributes/keyring-region
	$Region = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/attributes/region
	$Keyring = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/attributes/keyring
	$GcsPrefix = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/attributes/gcs-prefix

	Write-Host "Fetching admin credentials..."
	
	# fetch domain admin credentials
	If ($GcsPrefix.EndsWith("/")) {
	$GcsPrefix = $GcsPrefix -Replace ".$"
	}
	$TempFile = New-TemporaryFile

	# invoke-command sees gsutil output as an error so redirect stderr to stdout and stringify to suppress
	gsutil cp $GcsPrefix/output/domain-admin-password.bin $TempFile.FullName 2>&1 | %{ "$_" }

	$DomainAdminPassword = $(gcloud kms decrypt --key $KmsKey --location $KmsRegion --keyring $Keyring --ciphertext-file $TempFile.FullName --plaintext-file - | ConvertTo-SecureString -AsPlainText -Force)

	Remove-Item $TempFile.FullName

	<#$DomainAdminCredentials = New-Object `
			-TypeName System.Management.Automation.PSCredential `
			-ArgumentList "$NetBiosName\Administrator",$DomainAdminPassword#>
	Write-Host "Domain is $Domain"

	$DomainAdminCredentials = New-Object `
			-TypeName System.Management.Automation.PSCredential `
			-ArgumentList "$Domain\Administrator", $DomainAdminPassword

	Write-Host "Joining domain... using credential $DomainAdminCredentials"
	Add-Computer -DomainName $Domain -Credential $DomainAdminCredentials

	$RuntimeConfig = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/attributes/runtime-config
	Write-Host "Runtime config is $RuntimeConfig"

	#Now write the status-config-url for the c2d scripts
	#It needs to be the full path
	$Script:run_time_base = 'https://runtimeconfig.googleapis.com/v1beta1'
	$name = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/name
	$zone = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/zone
	$projectId = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri  http://169.254.169.254/computeMetadata/v1/instance/attributes/project-id

	gcloud compute instances add-metadata "$name" --zone $zone --metadata "status-config-url=$Script:run_time_base/projects/$projectId/configs/$RuntimeConfig"

	Write-Host "setting status-config-url=$Script:run_time_base/projects/$projectId/configs/$RuntimeConfig"

	try {
		Write-Host "Done adding to domain, adding key to reg: HKLM:\SOFTWARE\Google\SQLOnDomain"
		$result = New-Item -Path "HKLM:\SOFTWARE\Google\SQLOnDomain" -Force
	  }
	  catch [System.IO.IOException] {
		Write-Log "$_.Exception.Message"
		Write-Log "Error writing to registry $result"
	  }
}


$PostJoinScriptUrl = Get-GoogleMetadata "instance/attributes/post-join-script-url"
If ($PostJoinScriptUrl) {

	Write-Host "Configuring startup metadata for post-join script..."
	# set post join url as startup script then restart
	$name = Get-GoogleMetadata "instance/name"
	$zone = Get-GoogleMetadata "instance/zone"
	gcloud compute instances add-metadata "$name" --zone $zone --metadata "windows-startup-script-url=$PostJoinScriptUrl"

	Write-Host "Restarting..."
	Restart-Computer

}
Else {

	Write-Host "Configuring startup metadata..."
        # remove startup script from metadata to prevent rerun on reboot
        $name = Get-GoogleMetadata "instance/name"
        $zone = Get-GoogleMetadata "instance/zone"
        gcloud compute instances remove-metadata "$name" --zone $zone --keys windows-startup-script-url

	Write-Host "Signaling completion..."
	
	# flag completion of bootstrap requires beta gcloud component
	$name = Get-GoogleMetadata "instance/name"
	$RuntimeConfig = Get-GoogleMetadata "instance/attributes/runtime-config"
	
	Set-RuntimeConfigVariable -ConfigPath $RuntimeConfig -Variable bootstrap/$name/success/time -Text (Get-Date -Format g)

}
