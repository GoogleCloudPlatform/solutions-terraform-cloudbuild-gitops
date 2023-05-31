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

<#
  .SYNOPSIS
    GCE Base Modules.
  .DESCRIPTION
    Base modules needed for GCE Powershell scripts to run scripts to run.

  #requires -version 3.0
#>

# Default Values
$global:write_to_serial = $false
$global:metadata_server = 'metadata.google.internal'
$global:hostname = [System.Net.Dns]::GetHostName()
$global:log_file = $null

# Functions
function _AddToPath {
 <#
    .SYNOPSIS
      Adds GCE tool dir to SYSTEM PATH
    .DESCRIPTION
      This is a helper function which adds location to path
  #>
  param (
    [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
    [Alias('path')]
      $path_to_add
  )

  # Check if folder exists on the file system.
  if (!(Test-Path $path_to_add)) {
    Write-Log "$path_to_add does not exist, cannot be added to $env:PATH."
    return
  }

  try {
    $path_reg_key = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
    $current_path = (Get-ItemProperty $path_reg_key).Path
    $check_path = ($current_path).split(';') | ? {$_ -like $path_to_add}
  }
  catch {
    Write-Log 'Could not read path from the registry.'
    _PrintError
  }
  # See if the folder is already in the path.
  if ($check_path) {
    Write-Log 'Folder already in system path.'
  }
  else {
    try {
      Write-Log "Adding $path_to_add to SYSTEM path."
      $new_path = $current_path + ';' + $path_to_add
      $env:Path = $new_path
      Set-ItemProperty $path_reg_key -name 'Path' -value $new_path
    }
    catch {
      Write-Log 'Failed to add to SYSTEM path.'
      _PrintError
    }
  }
}


function Clear-EventLogs {
  <#
    .SYNOPSIS
      Clear all eventlog enteries.
    .DESCRIPTION
      This uses the Get-Eventlog and Clear-EventLog powershell functions to
      clean the eventlogs for a machine.
  #>

  Write-Log 'Clearing events in EventViewer.'
  Get-WinEvent -ListLog * |
    Where-Object {($_.IsEnabled -eq 'True') -and ($_.RecordCount -gt 0)} |
    ForEach-Object {
      try{[System.Diagnostics.Eventing.Reader.EventLogSession]::GlobalSession.ClearLog($_.LogName)}catch{}
    }
}


function Clear-TempFolders {
  <#
    .SYNOPSIS
      Delete all files from temp folder location.
    .DESCRIPTION
      This function calls an array variable which contain location of all the
      temp files and folder which needs to be cleared out. We use the
      Remove-Item routine to delete the files in the temp directories.
  #>

  # Array of files and folder that need to be deleted.
  @("C:\Windows\Temp\*", "C:\Windows\Prefetch\*",
    "C:\Documents and Settings\*\Local Settings\temp\*\*",
    "C:\Users\*\Appdata\Local\Temp\*\*",
    "C:\Users\*\Appdata\Local\Microsoft\Internet Explorer\*",
    "C:\Users\*\Appdata\LocalLow\Temp\*\*",
    "C:\Users\*\Appdata\LocalLow\Microsoft\Internet Explorer\*") | ForEach-Object {
    if (Test-Path $_) {
      Remove-Item $_ -recurse -force -ErrorAction SilentlyContinue
    }
  }
}


function Get-MetaData {
  <#
    .SYNOPSIS
      Get attributes from GCE instances metadata.
    .DESCRIPTION
      Use Net.WebClient to fetch data from metadata server.
    .PARAMETER property
      Name of instance metadata property we want to fetch.
    .PARAMETER filename
      Name of file to save metadata contents to.  If left out, returns contents.
    .EXAMPLE
      $hostname = _FetchFromMetaData -property 'hostname'
      Get-MetaData -property 'startup-script' -file 'script.bat'
  #>
  param (
    [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
    $property,
    $filename = $null,
    [switch] $project_only = $false,
    [switch] $instance_only = $false
  )

  $request_url = '/computeMetadata/v1/instance/'
  if ($project_only) {
    $request_url = '/computeMetadata/v1/project/'
  }

  $url = "http://$global:metadata_server$request_url$property"

  try {
    $client = _GetWebClient
    #Header
    $client.Headers.Add('Metadata-Flavor', 'Google')
    # Get Data
    if ($filename) {
      $client.DownloadFile($url, $filename)
      return
    }
    else {
      return ($client.DownloadString($url)).Trim()
    }
  }
  catch [System.Net.WebException] {
    if ($project_only -or $instance_only) {
      Write-Log "$property value is not set or metadata server is not reachable."
    }
    else {
      return (_FetchFromMetaData -project_only -property $property -filename $filename)
    }
  }
  catch {
    Write-Log "Unknown error in reading $url."
    _PrintError
  }
}


function _GenerateRandomPassword {
  <#
    .SYNOPSIS
      Generates random password which meet windows complexity requirements.
    .DESCRIPTION
      This function generates a password to be set on built-in account before
      it is disabled.
    .OUTPUTS
      Returns String
    .EXAMPLE
      _GeneratePassword
  #>

  # Define length of the password. Maximum and minimum.
  [int] $pass_min = 20
  [int] $pass_max = 35
  [string] $random_password = $null

  # Random password length should help prevent masking attacks.
  $password_length = Get-Random -Minimum $pass_min -Maximum $pass_max

  # Choose a set of ASCII characters we'll use to generate new passwords from.
  $ascii_char_set = $null
  for ($x=33; $x -le 126; $x++) {
    $ascii_char_set+=,[char][byte]$x
  }

  # Generate random set of characters.
  for ($loop=1; $loop -le $password_length; $loop++) {
    $random_password += ($ascii_char_set | Get-Random)
  }
  return $random_password
}


function _GetCOMPorts  {
  <#
    .SYNOPSIS
      Get available serial ports. Check if a port exists, if yes returns $true
    .DESCRIPTION
      This function is used to check if a port exists on this machine.
    .PARAMETER $portname
      Name of the port you want to check if it exists.
    .OUTPUTS
      [boolean]
    .EXAMPLE
      _GetCOMPorts
  #>

  param (
    [parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
      [String]$portname
  )

  $exists = $false
  try {
    # Read available COM ports.
    $com_ports = [System.IO.Ports.SerialPort]::getportnames()
    if ($com_ports -match $portname) {
      $exists = $true
    }
  }
  catch {
    _PrintError
  }
  return $exists
}


function _GetWebClient {
  <#
    .SYNOPSIS
      Get Net.WebClient object.
    .DESCRIPTION
      Generata Webclient object for clients to use.
    .EXAMPLE
      $hostname = _GetWebClient
  #>
  $client = $null
  try {
    # WebClient to return.
    $client = New-Object Net.WebClient
  }
  catch [System.Net.WebException] {
    Write-Log 'Could not generate a WebClient object.'
    _PrintError
  }
  return $client
}


function _PrintError {
  <#
    .SYNOPSIS
      Prints Error Messages
    .DESCRIPTION
      This is a helper function which prints out error messages in catch
    .OUTPUTS
      Error message found during execution is printed out to the console.
    .EXAMPLE
      _PrintError
  #>

  # See all error objects.
  $error_obj = Get-Variable -Name Error -Scope 2 -ErrorAction SilentlyContinue
  if ($error_obj) {
    try {
      $message = $($error_obj.Value.Exception[0].Message)
      $line_no = $($error_obj.Value.InvocationInfo[0].ScriptLineNumber)
      $line_info = $($error_obj.Value.InvocationInfo[0].Line)
      $hresult = $($error_obj.Value.Exception[0].HResult)
      $calling_script = $($error_obj.Value.InvocationInfo[0].ScriptName)

      # Format error string
      if ($error_obj.Value.Exception[0].InnerException) {
        $inner_msg = $error_obj.Value.Exception[0].InnerException.Message
        $errmsg = "$inner_msg  : $message {Line: $line_no : $line_info, HResult: $hresult, Script: $calling_script}"
      }
      else {
        $errmsg = "$message {Line: $line_no : $line_info, HResult: $hresult, Script: $calling_script}"
      }
      # Write message to output.
      Write-Log $errmsg -error
    }
    catch {
      Write-Log $_.Exception.GetBaseException().Message -error
    }
  }

  # Clear out the error.
  $error.Clear() | Out-Null
}


function Invoke-ExternalCommand {
  <#
    .SYNOPSIS
      Run External Command.
    .DESCRIPTION
      This function calls an external command outside of the powershell script and logs the output.
    .PARAMETER Executable
      Executable that needs to be run.
    .PARAMETER Arguments
      Arguments for the executable. Default is NULL.
    .EXAMPLE
      Invoke-ExternalCommand dir c:\
  #>
 [CmdletBinding(SupportsShouldProcess=$true)]
  param (
    [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
      [string]$Executable,
    [Parameter(ValueFromRemainingArguments=$true,
               ValueFromPipelineByPropertyName=$true)]
      $Arguments = $null
  )
  Write-Log "Running '$Executable' with arguments '$Arguments'"
  $out = &$Executable $Arguments 2>&1 | Out-String
  if ($out.Trim()) {
    $out.Trim().Split("`n") | ForEach-Object {
      Write-Log "--> $_"
    }
  }
}


function _TestAdmin {
  <#
    .SYNOPSIS
      Checks if the current Powershell instance is running with
      elevated privileges or not.
    .OUTPUTS
      System.Boolean
      True if the current Powershell is elevated, false if not.
  #>
  try {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal -ArgumentList $identity
    return $principal.IsInRole( [Security.Principal.WindowsBuiltInRole]::Administrator )
  }
  catch {
    Write-Log 'Failed to determine if the current user has elevated privileges.'
    _PrintError
  }
}


function _TestTCPPort {
  <#
    .SYNOPSIS
      Test TCP port on remote server
    .DESCRIPTION
      Use .Net Socket connection to connect to remote host and check if port is
      open.
    .PARAMETER remote_host
      Remote host you want to check TCP port for.
    .PARAMETER port_number
      TCP port number you want to check.
    .PARAMETER timeout
      Time you want to wait for.
    .RETURNS
      Return bool. $true if server is reachable at tcp port $false is not.
    .EXAMPLE
      _TestTCPPort -host 127.0.0.1 -port 80
  #>
  param (
   [Alias('host')]
    [string]$remote_host,
   [Alias('port')]
    [int]$port_number,
   [int]$timeout = 3000
  )

  $status = $false
  try {
    # Create a TCP Client.
    $socket = New-Object Net.Sockets.TcpClient
    # Use the TCP Client to connect to remote host port.
    $connection = $socket.BeginConnect($remote_host, $port_number, $null, $null)
    # Set the wait time
    $wait = $connection.AsyncWaitHandle.WaitOne($timeout, $false)
    if (!$wait) {
      # Connection failed, timeout reached.
      $socket.Close()
    }
    else {
      # Close the connection and report the error if there is one.
      $socket.EndConnect($connection) | Out-Null
      if (!$?) {
        Write-Log $error[0]
      }
      else {
        $status = $true
      }
      $socket.Close()
    }
  }
  catch {
    _PrintError
  }
  return $status
}


function Write-SerialPort {
  <#
    .SYNOPSIS
      Sending data to serial port.
    .DESCRIPTION
      Use this function to send data to serial port.
    .PARAMETER portname
      Name of port. The port to use (for example, COM1).
    .PARAMETER baud_rate
      The baud rate.
    .PARAMETER parity
      Specifies the parity bit for a SerialPort object.
      None: No parity check occurs (default).
      Odd: Sets the parity bit so that the count of bits set is an odd number.
      Even: Sets the parity bit so that the count of bits set is an even number.
      Mark: Leaves the parity bit set to 1.
      Space: Leaves the parity bit set to 0.
    .PARAMETER data_bits
      The data bits value.
    .PARAMETER stop_bits
      Specifies the number of stop bits used on the SerialPort object.
      None: No stop bits are used. This value is Currently not supported by the
            stop_bits.
      One:  One stop bit is used (default).
      Two:  Two stop bits are used.
      OnePointFive: 1.5 stop bits are used.
    .PARAMETER data
      Data to be sent to serial port.
    .PARAMETER wait_for_respond
      Wait for result of data sent.
    .PARAMETER close
      Remote close connection.
    .EXAMPLE
      Send data to serial port and exit.
      Write-SerialPort -portname COM1 -data 'Hello World'
    .EXAMPLE
      Send data to serial port and wait for respond.
      Write-SerialPort -portname COM1 -data 'dir C:\' -wait_for_respond
  #>
  [CmdletBinding(supportsshouldprocess=$true)]
  param (
    [parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
      [string]$portname,
    [Int]$baud_rate = 9600,
    [ValidateSet('None', 'Odd', 'Even', 'Mark', 'Space')]
      [string]$parity = 'None',
    [int]$data_bits = 8,
    [ValidateSet('None', 'One', 'Even', 'Two', 'OnePointFive')]
      [string]$stop_bits = 'One',
    [string]$data,
    [Switch]$wait_for_respond,
    [Switch]$close
  )

  if ($psCmdlet.shouldProcess($portname , 'Write data to local serial port')) {
    if ($close) {
      $data = 'close'
      $wait_for_respond = $false
    }
    try {
      # Define a new object to read serial ports.
      $port = New-Object System.IO.Ports.SerialPort $portname, $baud_rate, `
                          $parity, $data_bits, $stop_bits
      $port.Open()
      # Write to the serial port.
      $port.WriteLine($data)
      # If wait_for_resond is specified.
      if ($wait_for_respond) {
        $result = $port.ReadLine()
        $result.Replace("#^#","`n")
      }
      $port.Close()
    }
    catch {
      _PrintError
    }
  }
}


function Write-Log {
  <#
    .SYNOPSIS
      Generate Log for the script.
    .DESCRIPTION
      Generate log messages, if COM1 port found write output to COM1 also.
    .PARAMETER $msg
      Message that needs to be logged
    .PARAMETER $is_important
      Surround the message with a line of hyphens.
    .PARAMETER $is_error
      Mark messages as Error in red text.
    .PARAMETER $is_warning
      Mark messages as Warning in yellow text.
  #>
  param (
    [parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
      [String]$msg,
    [Alias('important')]
    [Switch] $is_important,
    [Alias('error')]
    [Switch] $is_error,
    [Alias('warning')]
    [Switch] $is_warning
  )
  $timestamp = $(Get-Date -Format 'yyyy/MM/dd HH:mm:ss')
  if (-not ($global:logger)) {
    $global:logger = ''
  }
  try {
    # Add a boundary around an important message.
    if ($is_important) {
      $boundary = '-' * 60
      $timestampped_msg = @"
${timestamp} ${global:logger}: ${boundary}
${timestamp} ${global:logger}: ${msg}
${timestamp} ${global:logger}: ${boundary}
"@
    }
    else {
      $timestampped_msg = "${timestamp} ${global:logger}: ${msg}"
    }
    # If a log file is set, use it.
    if ($global:log_file) {
      Add-Content $global:log_file "$timestampped_msg"
    }
    # If COM1 exists write msg to console.
    if ($global:write_to_serial) {
      Write-SerialPort -portname 'COM1' -data "$timestampped_msg" -ErrorAction SilentlyContinue
    }
    if ($is_error) {
      Write-Host "$timestampped_msg" -foregroundcolor red
    }
    elseif ($is_warning)  {
      Write-Host "$timestampped_msg" -foregroundcolor yellow
    }
    else {
      Write-Host "$timestampped_msg"
    }
  }
  catch {
    _PrintError
    continue
  }
}


function Set-LogFile {
  param (
    [parameter(Position=0, Mandatory=$true)]
      [String]$filename
  )
  Write-Log "Initializing log file $filename."
  if (Test-Path $filename) {
    Write-Log 'Log file already exists.'
    $global:log_file = $filename
  }
  else {
    try {
      Write-Log 'Creating log file.'
      New-Item $filename -Type File -ErrorAction Stop
      $global:log_file = $filename
    }
    catch {
      _PrintError
    }
  }
  Write-Log "Log file set to $global:log_file"
}


# Export all modules.
New-Alias -Name _WriteToSerialPort -Value Write-SerialPort
New-Alias -Name _RunExternalCMD -Value Invoke-ExternalCommand
New-Alias -Name _ClearEventLogs -Value Clear-EventLogs
New-Alias -Name _ClearTempFolders -Value Clear-TempFolders
New-Alias -Name _FetchFromMetadata -Value Get-Metadata
Export-ModuleMember -Function * -Alias *

if (_GetCOMPorts -portname 'COM1') {
  $global:write_to_serial = $true
}

# Clear out any existing errors.
$error.Clear() | Out-Null

# SIG # Begin signature block
# MIIXsQYJKoZIhvcNAQcCoIIXojCCF54CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUFYCbOohI0jAoGr8qlHX8EbQb
# OI6gghLXMIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
# AQUFADCBizELMAkGA1UEBhMCWkExFTATBgNVBAgTDFdlc3Rlcm4gQ2FwZTEUMBIG
# A1UEBxMLRHVyYmFudmlsbGUxDzANBgNVBAoTBlRoYXd0ZTEdMBsGA1UECxMUVGhh
# d3RlIENlcnRpZmljYXRpb24xHzAdBgNVBAMTFlRoYXd0ZSBUaW1lc3RhbXBpbmcg
# Q0EwHhcNMTIxMjIxMDAwMDAwWhcNMjAxMjMwMjM1OTU5WjBeMQswCQYDVQQGEwJV
# UzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNVBAMTJ1N5bWFu
# dGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMjCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBALGss0lUS5ccEgrYJXmRIlcqb9y4JsRDc2vCvy5Q
# WvsUwnaOQwElQ7Sh4kX06Ld7w3TMIte0lAAC903tv7S3RCRrzV9FO9FEzkMScxeC
# i2m0K8uZHqxyGyZNcR+xMd37UWECU6aq9UksBXhFpS+JzueZ5/6M4lc/PcaS3Er4
# ezPkeQr78HWIQZz/xQNRmarXbJ+TaYdlKYOFwmAUxMjJOxTawIHwHw103pIiq8r3
# +3R8J+b3Sht/p8OeLa6K6qbmqicWfWH3mHERvOJQoUvlXfrlDqcsn6plINPYlujI
# fKVOSET/GeJEB5IL12iEgF1qeGRFzWBGflTBE3zFefHJwXECAwEAAaOB+jCB9zAd
# BgNVHQ4EFgQUX5r1blzMzHSa1N197z/b7EyALt0wMgYIKwYBBQUHAQEEJjAkMCIG
# CCsGAQUFBzABhhZodHRwOi8vb2NzcC50aGF3dGUuY29tMBIGA1UdEwEB/wQIMAYB
# Af8CAQAwPwYDVR0fBDgwNjA0oDKgMIYuaHR0cDovL2NybC50aGF3dGUuY29tL1Ro
# YXd0ZVRpbWVzdGFtcGluZ0NBLmNybDATBgNVHSUEDDAKBggrBgEFBQcDCDAOBgNV
# HQ8BAf8EBAMCAQYwKAYDVR0RBCEwH6QdMBsxGTAXBgNVBAMTEFRpbWVTdGFtcC0y
# MDQ4LTEwDQYJKoZIhvcNAQEFBQADgYEAAwmbj3nvf1kwqu9otfrjCR27T4IGXTdf
# plKfFo3qHJIJRG71betYfDDo+WmNI3MLEm9Hqa45EfgqsZuwGsOO61mWAK3ODE2y
# 0DGmCFwqevzieh1XTKhlGOl5QGIllm7HxzdqgyEIjkHq3dlXPx13SYcqFgZepjhq
# IhKjURmDfrYwggSjMIIDi6ADAgECAhAOz/Q4yP6/NW4E2GqYGxpQMA0GCSqGSIb3
# DQEBBQUAMF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3Jh
# dGlvbjEwMC4GA1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBD
# QSAtIEcyMB4XDTEyMTAxODAwMDAwMFoXDTIwMTIyOTIzNTk1OVowYjELMAkGA1UE
# BhMCVVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTQwMgYDVQQDEytT
# eW1hbnRlYyBUaW1lIFN0YW1waW5nIFNlcnZpY2VzIFNpZ25lciAtIEc0MIIBIjAN
# BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAomMLOUS4uyOnREm7Dv+h8GEKU5Ow
# mNutLA9KxW7/hjxTVQ8VzgQ/K/2plpbZvmF5C1vJTIZ25eBDSyKV7sIrQ8Gf2Gi0
# jkBP7oU4uRHFI/JkWPAVMm9OV6GuiKQC1yoezUvh3WPVF4kyW7BemVqonShQDhfu
# ltthO0VRHc8SVguSR/yrrvZmPUescHLnkudfzRC5xINklBm9JYDh6NIipdC6Anqh
# d5NbZcPuF3S8QYYq3AhMjJKMkS2ed0QfaNaodHfbDlsyi1aLM73ZY8hJnTrFxeoz
# C9Lxoxv0i77Zs1eLO94Ep3oisiSuLsdwxb5OgyYI+wu9qU+ZCOEQKHKqzQIDAQAB
# o4IBVzCCAVMwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAO
# BgNVHQ8BAf8EBAMCB4AwcwYIKwYBBQUHAQEEZzBlMCoGCCsGAQUFBzABhh5odHRw
# Oi8vdHMtb2NzcC53cy5zeW1hbnRlYy5jb20wNwYIKwYBBQUHMAKGK2h0dHA6Ly90
# cy1haWEud3Muc3ltYW50ZWMuY29tL3Rzcy1jYS1nMi5jZXIwPAYDVR0fBDUwMzAx
# oC+gLYYraHR0cDovL3RzLWNybC53cy5zeW1hbnRlYy5jb20vdHNzLWNhLWcyLmNy
# bDAoBgNVHREEITAfpB0wGzEZMBcGA1UEAxMQVGltZVN0YW1wLTIwNDgtMjAdBgNV
# HQ4EFgQURsZpow5KFB7VTNpSYxc/Xja8DeYwHwYDVR0jBBgwFoAUX5r1blzMzHSa
# 1N197z/b7EyALt0wDQYJKoZIhvcNAQEFBQADggEBAHg7tJEqAEzwj2IwN3ijhCcH
# bxiy3iXcoNSUA6qGTiWfmkADHN3O43nLIWgG2rYytG2/9CwmYzPkSWRtDebDZw73
# BaQ1bHyJFsbpst+y6d0gxnEPzZV03LZc3r03H0N45ni1zSgEIKOq8UvEiCmRDoDR
# EfzdXHZuT14ORUZBbg2w6jiasTraCXEQ/Bx5tIB7rGn0/Zy2DBYr8X9bCT2bW+IW
# yhOBbQAuOA2oKY8s4bL0WqkBrxWcLC9JG9siu8P+eJRRw4axgohd8D20UaF5Mysu
# e7ncIAkTcetqGVvP6KUwVyyJST+5z3/Jvz4iaGNTmr1pdKzFHTx/kuDDvBzYBHUw
# ggTdMIIDxaADAgECAhAqnCGsqqY6PFinuTIr7pSNMA0GCSqGSIb3DQEBCwUAMH8x
# CzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3JhdGlvbjEfMB0G
# A1UECxMWU3ltYW50ZWMgVHJ1c3QgTmV0d29yazEwMC4GA1UEAxMnU3ltYW50ZWMg
# Q2xhc3MgMyBTSEEyNTYgQ29kZSBTaWduaW5nIENBMB4XDTE1MTIxNjAwMDAwMFoX
# DTE4MTIxNjIzNTk1OVowZDELMAkGA1UEBhMCVVMxEzARBgNVBAgMCkNhbGlmb3Ju
# aWExFjAUBgNVBAcMDU1vdW50YWluIFZpZXcxEzARBgNVBAoMCkdvb2dsZSBJbmMx
# EzARBgNVBAMMCkdvb2dsZSBJbmMwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
# AoIBAQDEDYLEQSko5f0MP6XHDma9pcSLs4qshAOfhC443waxTv0zYFg4Nt0iz9/x
# UB9H8VUFwYEB5yg+/1+JEgnq36oXSSxxq0jRnS70UeAD4PcWbHsMInVtfh9JxEMo
# iEHcbO0TKgOZ62IU+TUmbhIsA+L3gbkaBWcGfKYaW+0gFeUtg96ONvoeCEEcGkif
# tvHDLwITS6fKuu8cWG+O0w8UpAsrXbr0WqMNZDSlitePTSJmTaSu4fnNxljmxhF3
# Mt+63zlIitEn1zN3qMnkXu36Es/z/fruq4CGEzTrWn5vbBvu2EuyzHeYh6zK9btk
# b0keW5FjUB9jLYMncwefKxb0e3EpAgMBAAGjggFuMIIBajAJBgNVHRMEAjAAMA4G
# A1UdDwEB/wQEAwIHgDATBgNVHSUEDDAKBggrBgEFBQcDAzBmBgNVHSAEXzBdMFsG
# C2CGSAGG+EUBBxcDMEwwIwYIKwYBBQUHAgEWF2h0dHBzOi8vZC5zeW1jYi5jb20v
# Y3BzMCUGCCsGAQUFBwICMBkaF2h0dHBzOi8vZC5zeW1jYi5jb20vcnBhMB8GA1Ud
# IwQYMBaAFJY7U/B5M5evfYPvLivMyreGHnJmMCsGA1UdHwQkMCIwIKAeoByGGmh0
# dHA6Ly9zdi5zeW1jYi5jb20vc3YuY3JsMFcGCCsGAQUFBwEBBEswSTAfBggrBgEF
# BQcwAYYTaHR0cDovL3N2LnN5bWNkLmNvbTAmBggrBgEFBQcwAoYaaHR0cDovL3N2
# LnN5bWNiLmNvbS9zdi5jcnQwEQYJYIZIAYb4QgEBBAQDAgQQMBYGCisGAQQBgjcC
# ARsECDAGAQEAAQH/MA0GCSqGSIb3DQEBCwUAA4IBAQAj55OTr9uoTa+vVOjYJpWA
# zSORcO0LW7Hp2N0eQDd4lxjtn+WEZ4UGULXxq+aDWhd7Ub5/GMZHXiuq9KAfNT4F
# n0NA95/R9OGnAvOOyXH+GDdIQtfkNnMQktTY2RzEJlgYZ7YkImljAvdJUWt19rR9
# Vv8s9Ij3Z28IhvOLCzACf22S2U69mfd7dIYMy7mtLL9EeagAgpxi9KoR39K/8OGS
# KBGQu14ziIaWTd0Lr8NnoZUtRDLG+ve4gMFOOL4ftoT38SExZ0mon4p1B987OsPq
# cs1Af6fafMkufKkM8V1cgkJiuUmUj3DmpcBfF/tANsE6iWMDHD9moD2PoUxOXKy/
# MIIFWTCCBEGgAwIBAgIQPXjX+XZJYLJhffTwHsqGKjANBgkqhkiG9w0BAQsFADCB
# yjELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDlZlcmlTaWduLCBJbmMuMR8wHQYDVQQL
# ExZWZXJpU2lnbiBUcnVzdCBOZXR3b3JrMTowOAYDVQQLEzEoYykgMjAwNiBWZXJp
# U2lnbiwgSW5jLiAtIEZvciBhdXRob3JpemVkIHVzZSBvbmx5MUUwQwYDVQQDEzxW
# ZXJpU2lnbiBDbGFzcyAzIFB1YmxpYyBQcmltYXJ5IENlcnRpZmljYXRpb24gQXV0
# aG9yaXR5IC0gRzUwHhcNMTMxMjEwMDAwMDAwWhcNMjMxMjA5MjM1OTU5WjB/MQsw
# CQYDVQQGEwJVUzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xHzAdBgNV
# BAsTFlN5bWFudGVjIFRydXN0IE5ldHdvcmsxMDAuBgNVBAMTJ1N5bWFudGVjIENs
# YXNzIDMgU0hBMjU2IENvZGUgU2lnbmluZyBDQTCCASIwDQYJKoZIhvcNAQEBBQAD
# ggEPADCCAQoCggEBAJeDHgAWryyx0gjE12iTUWAecfbiR7TbWE0jYmq0v1obUfej
# DRh3aLvYNqsvIVDanvPnXydOC8KXyAlwk6naXA1OpA2RoLTsFM6RclQuzqPbROlS
# Gz9BPMpK5KrA6DmrU8wh0MzPf5vmwsxYaoIV7j02zxzFlwckjvF7vjEtPW7ctZlC
# n0thlV8ccO4XfduL5WGJeMdoG68ReBqYrsRVR1PZszLWoQ5GQMWXkorRU6eZW4U1
# V9Pqk2JhIArHMHckEU1ig7a6e2iCMe5lyt/51Y2yNdyMK29qclxghJzyDJRewFZS
# AEjM0/ilfd4v1xPkOKiE1Ua4E4bCG53qWjjdm9sCAwEAAaOCAYMwggF/MC8GCCsG
# AQUFBwEBBCMwITAfBggrBgEFBQcwAYYTaHR0cDovL3MyLnN5bWNiLmNvbTASBgNV
# HRMBAf8ECDAGAQH/AgEAMGwGA1UdIARlMGMwYQYLYIZIAYb4RQEHFwMwUjAmBggr
# BgEFBQcCARYaaHR0cDovL3d3dy5zeW1hdXRoLmNvbS9jcHMwKAYIKwYBBQUHAgIw
# HBoaaHR0cDovL3d3dy5zeW1hdXRoLmNvbS9ycGEwMAYDVR0fBCkwJzAloCOgIYYf
# aHR0cDovL3MxLnN5bWNiLmNvbS9wY2EzLWc1LmNybDAdBgNVHSUEFjAUBggrBgEF
# BQcDAgYIKwYBBQUHAwMwDgYDVR0PAQH/BAQDAgEGMCkGA1UdEQQiMCCkHjAcMRow
# GAYDVQQDExFTeW1hbnRlY1BLSS0xLTU2NzAdBgNVHQ4EFgQUljtT8Hkzl699g+8u
# K8zKt4YecmYwHwYDVR0jBBgwFoAUf9Nlp8Ld7LvwMAnzQzn6Aq8zMTMwDQYJKoZI
# hvcNAQELBQADggEBABOFGh5pqTf3oL2kr34dYVP+nYxeDKZ1HngXI9397BoDVTn7
# cZXHZVqnjjDSRFph23Bv2iEFwi5zuknx0ZP+XcnNXgPgiZ4/dB7X9ziLqdbPuzUv
# M1ioklbRyE07guZ5hBb8KLCxR/Mdoj7uh9mmf6RWpT+thC4p3ny8qKqjPQQB6rqT
# og5QIikXTIfkOhFf1qQliZsFay+0yQFMJ3sLrBkFIqBgFT/ayftNTI/7cmd3/SeU
# x7o1DohJ/o39KK9KEr0Ns5cF3kQMFfo2KwPcwVAB8aERXRTl4r0nS1S+K4ReD6bD
# dAUK75fDiSKxH3fzvc1D1PFMqT+1i4SvZPLQFCExggREMIIEQAIBATCBkzB/MQsw
# CQYDVQQGEwJVUzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xHzAdBgNV
# BAsTFlN5bWFudGVjIFRydXN0IE5ldHdvcmsxMDAuBgNVBAMTJ1N5bWFudGVjIENs
# YXNzIDMgU0hBMjU2IENvZGUgU2lnbmluZyBDQQIQKpwhrKqmOjxYp7kyK+6UjTAJ
# BgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0B
# CQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAj
# BgkqhkiG9w0BCQQxFgQUEeKZi2AXA3etQbuOeFvREFxZ4nIwDQYJKoZIhvcNAQEB
# BQAEggEAV4qbSXmlMNe8uP5tkPpfES6lxflrSHalr1+lEh9wfXrxR7LKvhdaOblM
# rTxxQJBe6RGU3Ag86xWcByCQsUmHekCs2x1lTR/g3xFRWqpKvu4HIiB8iykZMgmu
# aOvWBLBAxJ2gci1DELF+fTiBfmy8Jcz1UX0OOOwkgsvLbBVlU5SPZ150e0DdSfjh
# nt3MVCBKDUNQ99hKDaWvqjdj/VX34/ExuEOBroxflTVWM21jMkRQ8aIEz940coGi
# oB0l6GfGQy/VMsWgU7W4IEPpXH6gmI9EIwuzN+eim9N5xwGHqI/s/LzFpneX8pCX
# 7jsAe9SYrWYU5LEoo0SmS/YcN4ymcqGCAgswggIHBgkqhkiG9w0BCQYxggH4MIIB
# 9AIBATByMF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3Jh
# dGlvbjEwMC4GA1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBD
# QSAtIEcyAhAOz/Q4yP6/NW4E2GqYGxpQMAkGBSsOAwIaBQCgXTAYBgkqhkiG9w0B
# CQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0xODA3MTgxNjQ2MzRaMCMG
# CSqGSIb3DQEJBDEWBBTDikzGBpDxGcjAeJBYtTj2DhEVbDANBgkqhkiG9w0BAQEF
# AASCAQCLISKydxm1Pdur6eSZVdFTmG2+ift7J11+8fc10/TJr2VXv0tlrVgwadkw
# hyp0ceXleVUXZ9sqw2D734jRPottGQKiQkQqBtTf8qF0NqpTXbhA7aBjFCC+wZXP
# 0NkzGI9DLcLe6q+l2Mo7MY96jXID3bTjIBI52Mp1zEWDWhkeFjPCDdHWw03X4g0X
# TXisAW/mHmMHYdXVXvDrY2ym9wyz4DIO4pWCSIdCA/4FT/G7yY0ba1H5N1hiLBd6
# 9wl922GdZx00p7clwF2OZCH1jLTBfKaSd1NcUonG8oeoQiR2Lm3qoeMnc2uLdw0j
# fwsDpip2ZPs2e7ws+jxs1UoNNc3g
# SIG # End signature block
