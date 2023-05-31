# Copyright 2017 Google Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

<#
  .SYNOPSIS
    C2D Base Modules.
  .DESCRIPTION
    Base modules needed for C2D Powershell scripts to run scripts to run.
  .NOTES
    LastModifiedDate: $Date: 2017/02/26 $
    Version: $Revision: #2 $

  #requires -version 3.0
#>


$Script:gce_install_dir = 'C:\Program Files\Google\Compute Engine\sysprep'
$Script:run_time_base = 'https://runtimeconfig.googleapis.com/v1beta1'

# Import Modules
try {
    Import-Module $script:gce_install_dir\gce_base.psm1 -ErrorAction Stop
}
catch [System.Management.Automation.ActionPreferenceStopException] {
    Write-Host $_.Exception.GetBaseException().Message
    Write-Host ("Unable to import GCE module from $script:gce_install_dir. " +
        'Check error message, or ensure module is present.')
    exit 2
}


# Functions
function _CreateRunTimeConfig {
    <#
    .SYNOPSIS
        Create a new run-time config.
    .DESCRIPTION
        Generate new run-time config for a given instance. 
         This will be separate from the deployment manager instance config.
    .EXAMPLE
        _CreateRunTimeConfig
    #>
    param (
    [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        $config_name
    )

    $project_id = _FetchFromMetaData -property 'project-id' -project_only
    $run_time_path = "projects/$project_id/configs"
    $newConfig = @{
      name = "$run_time_path/$config_name"
    }

    $json = $newConfig | ConvertTo-Json
    Write-Log "Writing a new startup watcher config: $json"

    # TODO: Need to add a check for exisiting path.
    if (_RunTimePost -path "$run_time_path/" -post $json) {
      return "$run_time_path/$config_name"
    }
    else {
      Write-Log "Failed to create ConfigName: $config_name" -error
    }
}

function _GetRuntimeConfig {
   <#
    .SYNOPSIS
        Fetched run-time config.
    .DESCRIPTION
        Get the URL for runtime config from the metadataserver
    .EXAMPLE
        _GetRuntimeConfig
    #>
    
    $config_name = $null
    # Get RuntimeConfig URL for the deployment
    $runtime_config = _FetchFromMetaData -property 'attributes/status-config-url'

    if ($runtime_config) {
      # Use second part of the config URL
      $config_name = (($runtime_config -split "$Script:run_time_base/")[1])
      return $config_name
    }
    else {
      Write-Log 'No RunTimeConfig found URL found in metadata.' -error
      return $false
    }
}

function _RunTimeQuery{
    <#
    .SYNOPSIS
        Do a POST/GET request
    .DESCRIPTION
        Is a sub function called to do POST request
    .EXAMPLE
        _RunTimeQuery -get -path <path>
    .EXAMPLE
        _RunTimeQuery -post -path <path> -body <body>
    #>
    param (
    [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        $access_token,
    [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        $path,
    [Alias('get')]
    [Switch] $get_req,
    [Alias('post')]
    [Switch] $post_req,
    [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $body
    )

    # Define URL
    $url = "$Script:run_time_base/$path"
    $header = @{"Authorization"="Bearer $access_token"}
    
    if ($get_req) {
      try {
        # GET request against a URL
        $response = Invoke-RestMethod -Uri $url -Method GET -Headers $header `
         -ErrorAction SilentlyContinue
        return $response 
      }
      catch [System.Net.WebException] {
        if ($_.Exception.Response) {
          if ($_.Exception.Response.StatusCode.value__ -eq 404){
            Write-Log "$url does not exist." -warning
            return $_.Exception.Response.StatusCode.value__
          }
          Write-Log $_.Exception.Response.StatusCode.value__ -error # This is the numeric version.
          Write-Log $_.Exception.Response.StatusCode -error # This is a System.Net.HttpStatusCode enum value
        }
        else {
          _PrintError
        }
        return $false
      }
    }
    elseif ($post_req){
      if(!$body){
        Write-Log "-body parameter is required with -post."
        return
      }
      $content_type = 'application/json'
      try {
        # POST request against a URL
        $response = Invoke-RestMethod -Uri $url -ContentType $content_type `
         -Method POST -Body $body -Headers $header `
         -ErrorAction SilentlyContinue
        return $response
      }
      catch [System.Net.WebException] {
        $response = $_.Exception.Response
        if ($response) {
          if ($response.StatusCode.value__ -eq 409){
            Write-Log "$path already exists." -warning
            return $response.StatusCode.value__
          }
          Write-Log "Failed to POST: $path"
          Write-Log $response.StatusCode -error # This is a System.Net.HttpStatusCode enum value
          Write-Log $response.StatusCode.value__ -error # This is the numeric version.
        }
        else {
          _PrintError
        }
        return $false
      }
      catch {
        _PrintError
        Write-Log $_.Exception.GetType().FullName -error
        Write-Log $_.Exception -error
        return $false
      }
    }
}

function CreateRunTimeVariable {
    <#
    .SYNOPSIS
        Create a new runtime variable during run time.
    .DESCRIPTION
        Generate new run time variable for the instance
    .EXAMPLE
        CreateRunTimeVariable -config_path -var_name
    #>
    param (
    [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        $config_path,
    [Alias('random')]
    [Switch] $random_var,
    [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        $var_name,
    [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $var_text,
    [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $var_value
    )
 
    # Get access Token to auth for RunTime
    try {
      $access_token = (_FetchFromMetaData -property `
       'service-accounts/default/token'| `
       ConvertFrom-Json).access_token
    }
    catch {
      _PrintError
      Write-Log $_.Exception.GetType().FullName -error
      Write-Log 'Failed to get access token for Runtime Config' -error
      return $false
    }

    if ($random_var) {
      $rand_num = Get-Random
      $var_name += "/$rand_num"
    }

    Write-Log "Writing $var_name -> $config_path"
    # Generate the body to create the key variable
    $variable = @{
      name = "$config_path/variables/$var_name"
    }
    
    $var_json = $variable | ConvertTo-Json
    
    # POST the request
    $response = _RunTimeQuery -post -path "$config_path/variables" `
     -body $var_json -access_token $access_token
    if ($response) {
      Write-Log "Created: $config_path/variables/$var_name, with response: $response"
      return $response
    }
    else{
      Write-Log "Failed to create RunTimeConfig: $config_path/variables" -error
      return $false
    }
}

function CreateSCTask {
    <#
    .SYNOPSIS
        Create a Scheduled Task.
    .DESCRIPTION
        Generate new scheduledTask Action
    .EXAMPLE
        CreateSCTask -task_name
    #>
    param (
    [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        $name,
    [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        $user,
    [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        $password,
    [Alias('file')]
    [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        $sch_file,
    [Alias('trigger')]
    [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $when_to_trigger
    )
 
    $trigger = $null
    Write-Log "Creating task $name"

    # Define trigger
    if ($when_to_trigger){
      $trigger = $when_to_trigger
    }
    else {
      $trigger = New-ScheduledTaskTrigger -AtStartup
    }

    $action = New-ScheduledTaskAction -Execute "powershell.exe" -argument `
     "-ExecutionPolicy Bypass -NonInteractive -NoProfile -File $sch_file -AsJob"
    $setting = New-ScheduledTaskSettingsSet
    try {
      Write-Log "Adding task: $name, with user: $script:domain_service_account."
      Register-ScheduledTask $name -Action $action -Trigger $trigger -Settings $setting `
       -User $user -Password $password -RunLevel Highest
    }
    catch {
      _PrintError
    }
}

function DeleteSCTask {
    <#
    .SYNOPSIS
        Deletes a Scheduled Task.
    .DESCRIPTION
        Deletes a scheduledTask Action
    .EXAMPLE
        DeleteSCTask -task_name
    #>
    param (
    [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        $name
    )
    Write-Log "Unregistering $name"
    try {
      Unregister-ScheduledTask -TaskName $name -Confirm:$false
    }
    catch {
      _PrintError
    }
}

function WaitForRuntime {
   <#
    .SYNOPSIS
        Waits for a runtime variable
    .DESCRIPTION
        Waits for a runtime variable before giving up
    .EXAMPLE
        WaitForRuntime -path $path -timeout
    #>
    param (
    [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        $path,
    [Alias('timeout')]
    [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $wait_time_min
    )
    # Get RuntimeConfig URL for the deployment
    $access_token = (_FetchFromMetaData -property `
      'service-accounts/default/token'| `
       ConvertFrom-Json).access_token
    $runtime_config = _GetRuntimeConfig
    $query_path = "$runtime_config/variables/$path"

    Write-Logger "Querying path $query_path"
    if ($wait_time_min) {
      for ($i=0; $i -le $wait_time_min; $i++) {
        $response = _RunTimeQuery -get -path $query_path -access_token $access_token
        
        if($response) {
          if ($response -eq 404) {
            Write-Logger "$query_path not available. Will retry after 60 seconds.."
            Start-Sleep -s 60
          }
          else {
            Write-Logger "$query_path is available."
            return $response
           }
        }
        else {
          Write-Logger "Something went wrong"
          return $false
        }
      }
    }
    else {
      return _RunTimeQuery -get -path $query_path -access_token $access_token
    }
}

function Write-Logger {
    param (
      [parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
      [AllowEmptyString()]
      [string]$data,
      [string]$port = 'COM1'
    )
    
    $timestamp = $(Get-Date)
    $timestampped_msg = "$timestamp  $data"
    try {
      # define a new object to read serial ports
      $serial_port = New-Object System.IO.Ports.SerialPort $port, 9600, None, 8, One
      $serial_port.Open()
      # Write to the serial port
      $serial_port.WriteLine($timestampped_msg)
      Write-Host $timestampped_msg
    }
    catch {
      Write-Host 'Error writing to serial port'
      continue
    }
    finally {
      if ($serial_port) {
        $serial_port.Close()
      }
    }
}

function Write-ToReg {
    <#
    .SYNOPSIS
        Write To registry
    .DESCRIPTION
        Write a key to regisry
    .EXAMPLE
        Write-ToReg
    #>
    param (
    [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        $path
    )
    # Create registry key
    try {
      $result = New-Item -Path $path -Force
      return $true
    }
    catch [System.IO.IOException] {
      Write-Log "$_.Exception.Message"
      Write-Log $result
      return $false
    }
}

function UpdateRunTimeWaiter {
    <#
    .SYNOPSIS
        Updtes a RunTimeWaiter.
    .DESCRIPTION
        Update RunTimeWaiter POST to a given path. By default writes to success
    .EXAMPLE
        UpdateRunTimeWaiter
    .EXAMPLE
        UpdateRunTimeWaiter -failure 
    #>
    param (
    [Switch] $failure,
    [Alias('path')]
    [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $status_var_path
    )

    $key_path = $null
    $config_name = _GetRuntimeConfig

    if(!$config_name){
      Write-Log "Could not find runtime_config from metadata server" -error
      return $false
    }

    if (!$status_var_path) {
      $status_var_path = _FetchFromMetaData -property `
       'attributes/status-variable-path'
    }
    else {
      Write-Log "Writing to custom subpath: $status_var_path"
    }

    if ($failure) {
      $key_path = "$status_var_path/failure"
    }
    else {
      $key_path = "$status_var_path/success"
    }

    $response = CreateRunTimeVariable -config_path $config_name -var_name $key_path -random
}

# Export all modules.
Export-ModuleMember -Function * -Alias *

# Clear out any existing errors.
$error.Clear() | Out-Null