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
    Write-Host "$Url"

	Return Invoke-RestMethod @Params
}

Function Wait-RuntimeConfigWaiter {
	Param(
		[Parameter(Mandatory=$True)][String] $ConfigPath,
		[Parameter(Mandatory=$True)][String] $Waiter,
		[int] $Sleep = 60
	)
	$RuntimeWaiter = $Null

    Write-Host $ConfigPath/waiters/$Waiter

    While (($RuntimeWaiter -eq $Null) -Or (-Not $RuntimeWaiter.done)) {
		$RuntimeWaiter = Get-RuntimeConfigWaiter -ConfigPath $ConfigPath -Waiter $Waiter
		If (-Not $RuntimeWaiter.done) {
			Write-Host "Waiting for [$ConfigPath/waiters/$Waiter]..."
			Sleep $Sleep
		}
	}
	Return $RuntimeWaiter
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


Function List-RuntimeConfigWaiter {
	Param(
		[Parameter(Mandatory=$True)][String] $ConfigPath
	)

	$RuntimeWaiter = $Null

    Write-Host $ConfigPath/waiters

	$Auth = $(gcloud auth print-access-token)

	$Url = "https://runtimeconfig.googleapis.com/v1beta1/$ConfigPath/waiters"

    $Headers = @{
	    Authorization="Bearer " + $Auth
	}

    Write-Host "$Url"

    Return Invoke-RestMethod -Uri $Url -Headers $Headers -Method 'Get'
}

Function DeleteAllWaiters{
	Param(
		[Parameter(Mandatory=$True)][String] $ConfigPath
	)

    $List = List-RuntimeConfigWaiter -ConfigPath $RuntimeConfig

    foreach($waiter in $List.waiters){
        $waiterName=$waiter.name.Substring($waiter.name.LastIndexOf("/")+1, $waiter.name.Length - $waiter.name.LastIndexOf("/")-1)
        Write-Host $waiterName
        Delete-RuntimeConfigWaiter -ConfigPath $ConfigPath -Waiter $waiterName
    }
}

$RuntimeConfig = "projects/{project-name}/configs/acme-config"
$Waiter = "waiter41"

$Result = List-RuntimeConfigWaiter -ConfigPath $RuntimeConfig

foreach($waiter in $Result.waiters){
    Write-Host $waiter
}

$DeleteResult=DeleteAllWaiters -ConfigPath $RuntimeConfig

try{
    Delete-RuntimeConfigWaiter -ConfigPath $RuntimeConfig `
        -Waiter $Waiter
}Catch{
    Write-Host "Error"
    Write-Host $_.Exception.Message
}


try{
    Create-RuntimeConfigWaiter -ConfigPath $RuntimeConfig `
        -Waiter $Waiter `
        -Timeout 100 `
        -SuccessPath 'bootstrap/acme-sandbox-win-p-01/success' `
        -SuccessCardinality 1
        #-FailurePath 'bootstrap/acme-sandbox-win-p-01/failure' `
        #-FailureCardinality 1
}Catch{
    Write-Host "Error"
    Write-Host $_.Exception.Message
}


try{
    Wait-RuntimeConfigWaiter -ConfigPath $RuntimeConfig -Waiter $Waiter
    #$thewaiter = Get-RuntimeConfigWaiter -ConfigPath $RuntimeConfig -Waiter $Waiter
    Write-Host $thewaiter
} Catch{
Write-Host "Error"
    Write-Host $_.Exception.Message
}

Write-Host "Bootstrap script ended..."
