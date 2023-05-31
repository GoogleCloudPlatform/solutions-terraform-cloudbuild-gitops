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
    SQL Server Configuration

  .DESCRIPTION
    This Script bootstrap SQL Server Configuration
  .EXAMPLE
    sql_bootstrap.ps1
  .EXAMPLE
    sql_bootstrap.ps1 -name

  #requires -version 3.0
#>
[CmdletBinding()]
param (
  [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
      $task_name=$false,
  [Alias('AsJob')]
  [Switch] $as_job
)

Set-StrictMode -Version Latest

$script:c2d_dir = 'C:\C2D'

# Import Modules
try {
    Import-Module $script:c2d_dir\c2d_base.psm1 -ErrorAction Stop
}
catch [System.Management.Automation.ActionPreferenceStopException] {
    Write-Host $_.Exception.GetBaseException().Message
    Write-Host ("Unable to import GCE module from $script:c2d_dir. " +
        'Check error message, or ensure module is present.')
    exit 2
}

# Default Values
$Script:all_nodes = @()
$Script:all_nodes_csv = $null
$Script:all_nodes_fqdn = @()
$Script:backup_key_path = 'backup'
$Script:cluster_name = 'cluster-dbclus'
$Script:cluster_key_path = 'cluster'
$Script:cred_obj = $null
$Script:db_name = 'TestDB'
$Script:db_folder_data = 'SQLData'
$Script:db_folder_log = 'SQLLog'
$Script:db_folder_backup = 'SQLBackup'
$Script:initdb_key_path = 'initdb'
$Script:domain_bios_name = $null
$Script:domain_name = $null
$script:domain_service_account = $null
$script:name_ag = 'cluster-ag' # Name of the SQLServer Availability Group
$script:name_ag_listener= 'cluster-listener'
$script:node2 = $null
$Script:replica_key_path = 'replica'
$script:remote_nodes = @()
$script:sa_password = $null
$Script:static_ip = @()
$Script:static_listner_ip = @()
$Script:service_account = $null
$script:show_msgs = $false
$script:write_to_serial = $false

# Functions

Function Unwrap-SecureString() {
	Param(
		[System.Security.SecureString] $SecureString
	)
	Return (New-Object -TypeName System.Net.NetworkCredential -ArgumentList '', $SecureString).Password
}

function _AvailabilityReplica {
    Write-Logger "Creating SqlAvailabilityReplica on $Global:hostname"
    $initialized_nodes = @()

    # Find the version of SQL Server running
    $Srv = Get-Item SQLSERVER:\SQL\$($Global:hostname)\DEFAULT
    $Version = ($Srv.Version)
    $CommitMode = 'SynchronousCommit'
    $FailoverMode = 'Automatic'

    try {

      ForEach($node in $Script:all_nodes) {
        # Create an in-memory representation of the primary replica
        if ($node.EndsWith(3)){
          $CommitMode = 'AsynchronousCommit'
          $FailoverMode='Manual'
        }

        $initialized_nodes += New-SqlAvailabilityReplica `
          -Name $node `
          -EndpointURL "TCP://$($node).$($Script:domain_name):5022" `
          -AvailabilityMode $CommitMode `
          -FailoverMode $FailoverMode `
          -Version $Version `
          -AsTemplate
      }
      return $initialized_nodes
    }
    catch{
      Write-Logger $_.Exception.GetType().FullName
      Write-Logger "$_.Exception.Message"
      return $false
    }
}

function _BackUpDataBase {
    # Backup my database and its log on the primary
    Write-Logger "Creating backups of database $Script:db_name on $script:node2"
    try {
      # backup DB
      $backupDB = "\\$script:node2\$Script:db_folder_backup\$($Script:db_name)_db.bak"
      Backup-SqlDatabase `
        -Database $Script:db_name `
        -BackupFile $backupDB `
        -ServerInstance $Global:hostname `
        -Initialize
      # Backup log
      $backupLog = "\\$script:node2\$Script:db_folder_backup\$($db_name)_log.bak"
      Backup-SqlDatabase `
        -Database $Script:db_name `
        -BackupFile $backupLog `
        -ServerInstance $Global:hostname `
        -BackupAction Log -Initialize
      return $true
    }
    catch {
      Write-Logger $_.Exception.GetType().FullName
      Write-Logger "$_.Exception.Message"
      return $false
    }
}

function _CreateEndPoint {
    Write-Logger "Creating endpoint on node $Global:hostname"
    # Creating endpoint
    try {
      $endpoint = New-SqlHadrEndpoint "Hadr_endpoint" `
       -Port 5022 `
       -Path "SQLSERVER:\SQL\$Global:hostname\Default"
      Set-SqlHadrEndpoint -InputObject $endpoint -State "Started"
      return $true
    }
    catch [System.Data.SqlClient.SqlException] {
      Write-Logger "'Hadr_endpoint' already exists."
      return $true
    }
    catch {
      Write-Logger $_.Exception.GetType().FullName
      Write-Logger "$_.Exception.Message"
      return $false
    }
}

function _DBPermission {
    # Grant connect permissions to the endpoints
    ForEach($node in $script:remote_nodes)
    {
        # Grant connect permissions to the endpoints
        $query = " `
          IF SUSER_ID('$($node)') IS NULL CREATE LOGIN [$($node)] FROM WINDOWS `
          GO
          GRANT CONNECT ON ENDPOINT::[Hadr_endpoint] TO [$($node)] `
          GO `
          IF EXISTS(SELECT * FROM sys.server_event_sessions WHERE name='AlwaysOn_health') `
          BEGIN `
            ALTER EVENT SESSION [AlwaysOn_health] ON SERVER WITH (STARTUP_STATE=ON); `
          END `
          IF NOT EXISTS(SELECT * FROM sys.dm_xe_sessions WHERE name='AlwaysOn_health') `
          BEGIN `
            ALTER EVENT SESSION [AlwaysOn_health] ON SERVER STATE=START; `
          END `
    
          GO "

        try {
          Write-Logger "$node- Granting permission to endpoint"
          Write-Logger $query
          Invoke-Sqlcmd -Query $query
          return $true
        }
        catch {
          Write-Logger $_.Exception.GetType().FullName
          Write-Logger "$_.Exception.Message"
          return $false
        }
    }
}

function _EnableAlwaysOn {
    # Enable Always-On on all Server nodes
    ForEach($node in $Script:all_nodes){
      try {
        Write-Logger "Sleeping for 10s ...."
        Start-Sleep -s 10
        Write-Logger "Trying to enable AlwaysOn feature for $node"
        Enable-SqlAlwaysOn -ServerInstance $node -Force
        Write-Logger "-- AlwaysOn feature turned on for $node .. --"
      }
      catch [Microsoft.SqlServer.Management.Smo.FailedOperationException] {
        Write-Logger "ChangeHADRService failed for Service 'MSSQLSERVER' on node: $node"
        Write-logger "$Script:cluster_name is not setup correctly."
        return $false
      }
      catch {
        Write-Logger $_.Exception.GetType().FullName
        Write-Logger "$_.Exception.Message"
        return $false
      }
    }
    return $true
}

function _NewCluster {

    Write-Logger "Setting up cluster $Script:cluster_name for nodes $Script:all_nodes_fqdn and ips $Script:static_ip"
    # Create the cluster
    try {
      $result = New-Cluster -Name $Script:cluster_name -Node $Script:all_nodes_fqdn `
       -NoStorage -StaticAddress $Script:static_ip
      Write-Logger "Result for setup cluster: $result"
      return $true
    }
    catch {
      Write-Logger "** Failed to setup cluster: $Script:cluster_name ** "
      Write-Logger $_.Exception.GetType().FullName
      Write-Logger "$_.Exception.Message"
      return $false
    }
}

function _RestoreDataBase {
    Write-Logger "Restoring backups of database $Script:db_name on $Global:hostname"

    try {
      $backupDB = "\\$script:node2\$Script:db_folder_backup\$($Script:db_name)_db.bak"
      Write-Logger "Restoring DB from $backupDB"
      Restore-SqlDatabase `
        -Database $Script:db_name `
        -BackupFile $backupDB `
        -ServerInstance $Global:hostname `
        -NoRecovery -ReplaceDatabase
      # Restore Backup log
      $backupLog = "\\$script:node2\$Script:db_folder_backup\$($db_name)_log.bak"
      Write-Logger "Restoring Logs from $backupLog"
      Restore-SqlDatabase `
        -Database $Script:db_name `
        -BackupFile $backupLog `
        -ServerInstance $Global:hostname `
        -RestoreAction Log `
        -NoRecovery
      return $true
    }
    catch {
      Write-Logger $_.Exception.GetType().FullName
      Write-Logger "$_.Exception.Message"
      return $false
    }
}

function CheckIfNode1 {
    <#
    .SYNOPSIS
        Checks if the current host is Node1
    .DESCRIPTION
        If the current host is node1 we do treat it as primary
    .EXAMPLE
        CheckIfNode1
    #>

    if ($Global:hostname.EndsWith(1)){
      return $true
    }
}

function ConfigureAvailabiltyGroup {
   <#
    .SYNOPSIS
        ConfigureAvailabiltyGroup
    .DESCRIPTION
        Configures the newly created availability group
    .EXAMPLE
        ConfigureAvailabiltyGroup
    #>
    $initialized_nodes = @()
    if ((_CreateEndPoint) -and (_DBPermission)) {
      Write-Logger "-- Availability endpoints are configured for all nodes. --"

      if (CheckIfNode1) { # Backup Primary database
        if (_BackUpDataBase) {
          UpdateSubWaiter -key "$Script:backup_key_path/success/done"
        }
        else {
          UpdateSubWaiter -key "$Script:backup_key_path/failure/failed"
          return $false
        }
      }
      else {
        # Restore primary db on other nodes
        if ((WaitForRuntime -path "$Script:backup_key_path/success/done" -timeout 12)) {
          if (_RestoreDataBase) {
            Write-Logger "$Script:db_name database restored successfully on $Global:hostname"
            UpdateSubWaiter -key "$Script:initdb_key_path/success/done"
          }
          else {
            Write-Logger "Failed to restore $Script:db_name on $Global:hostname"
            UpdateSubWaiter -key "$Script:initdb_key_path/failure/failed"
            return $false
          }
        }
        else {
          Write-Logger "TimeOut exceeded while waiting on node(s) to finish backup/restore operation."
          return $false
        }
      }

      # Create the New-SqlAvailabilityReplica
      if ((WaitForRuntime -path "$Script:initdb_key_path/success/done" -timeout 12)) {
        if (CheckIfNode1) {
          $initialized_nodes = _AvailabilityReplica
          if ($initialized_nodes) {
            Write-Logger ("Availability replica has been set.")
            UpdateSubWaiter -key "$Script:replica_key_path/success/done"

            # Create the availability group
            Write-Logger "-- Create Availability Group: $Script:name_ag --"
            try {
              New-SqlAvailabilityGroup `
                -Name $Script:name_ag `
                -Path "SQLSERVER:\SQL\$($Global:hostname)\DEFAULT" `
                -AvailabilityReplica $initialized_nodes `
                -Database $Script:db_name
            }
            catch{
              Write-Logger "** Failed to create SqlAvailabilityGroup. **"
              Write-Logger $_.Exception.GetType().FullName
              Write-Logger "$_.Exception.Message"
              return $false
            }

            # Join other nodes to availability group.
            Write-Logger "-- Joining nodes to: $Script:name_ag --"
            ForEach($node in $Script:all_nodes) {
              Write-Logger " adding $node to the $Script:name_ag"
              if ($node.EndsWith(1)) {
                Write-Logger "Primary $node does not needed to be added to $Script:name_ag."
              }
              else {
                try {
                  Join-SqlAvailabilityGroup `
                    -Path "SQLSERVER:\SQL\$($node)\DEFAULT" `
                    -Name $Script:name_ag
                }
                catch {
                  Write-Logger "** Failed to join $node in AvailabilityGroup. **"
                  Write-Logger $_.Exception.GetType().FullName
                  Write-Logger "$_.Exception.Message"
                }

                # Join the secondary database to the availability group.
                Write-Logger "-- Join DB in $node to Availability Group. --"
                try {
                      # In SQL Server 2017 the Add-SqlAvailabilityDatabase was failing so decided to run it as a query instead
                      Invoke-Command -ComputerName $node -ScriptBlock {
                      param($db_name, $name_ag)
                  
                      $hostname = [System.Net.Dns]::GetHostName()
                      Write-Logger "$(Get-Date) $hostname - Adding database [$db_name] to Availability Group [$name_ag]"
                  
                      $query = "ALTER DATABASE [$db_name] SET HADR AVAILABILITY GROUP = [$name_ag]"
                      Write-Logger $query
                  
                      Invoke-Sqlcmd -Query $query
                  } -ArgumentList $Script:db_name, $Script:name_ag
                }
                catch {
                  Write-Logger "** Failed to join $Script:db_name on $node to $Script:name_ag. **"
                  Write-Logger $_.Exception.GetType().FullName
                  Write-Logger "$_.Exception.Message"
                }
              }
            }

            # Create the listener
            Write-Logger "-- Create Listener with IPs: $Script:static_listner_ip. --"
            try {
              New-SqlAvailabilityGroupListener `
                -Name $name_ag_listener `
                -StaticIp $Script:static_listner_ip `
                -Path SQLSERVER:\SQL\$($Global:hostname)\DEFAULT\AvailabilityGroups\$($Script:name_ag)
            }
            catch{
              Write-Logger "** Failed to add listeners to $Script:name_ag. **"
              Write-Logger $_.Exception.GetType().FullName
              Write-Logger "$_.Exception.Message"
              return $false
            }
          }
          else {
            Write-Logger "** Failed to initialize all db in sqlcluster **"
            UpdateSubWaiter -key "$Script:replica_key_path/failure/failed"
            return $false
          }
        }
      }
      else {
        Write-Logger "TimeOut exceeded while waiting on nodes to initialize db."
          return $false
      }

      # Check availability group
      if ((WaitForRuntime -path "$Script:replica_key_path/success/done" -timeout 12)) {
        Write-Logger "Waiting.."
      }
      else {
        return $true
      }
    }
    else {
      Write-Logger "Failed to create endpoints"
      return $false
    }
}

function CreateShares {
    <#
    .SYNOPSIS
        Creates Folders and shares on local machine
    .DESCRIPTION
        Creates folder and shares for SQL server HA needs
    .EXAMPLE
        CreateShares
    #>

    if (Test-Path -path $shares_already_created_reg) {
      Write-Log "Shares are already created. Nothing to do here..."
    }
    else {
      # Configure SQL Folders
      Write-Log "Create SQL Share Folders $Script:db_folder_data & $Script:db_folder_log"
      New-Item -ItemType directory -Path "C:\$Script:db_folder_data"
      New-Item -ItemType directory -Path "C:\$Script:db_folder_log"

      if ($Global:hostname.EndsWith(2)){ # Create backup share on node2 only
        Write-Log "Creating backup share $Script:db_folder_backup as $global:hostname is not the primary node."
        New-Item -ItemType directory -Path "C:\$Script:db_folder_backup"
        try {
          New-SMBShare -Name "$Script:db_folder_backup" -Path "C:\$Script:db_folder_backup" `
            -FullAccess 'Everyone'
        }
        catch {
          _PrintError
        }

        # Enable CredSSP on localhost and disable name checking
        if (!(CheckIfNode1)) {
          Write-Log "Enable CredSSP Client on $Global:hostname"
          try {
            Enable-WSManCredSSP Client -DelegateComputer * -Force
            # Wait 15 secs before enabling CredSSP in both servers
            # On occasions got errors when running the command that follows without waiting
            Start-Sleep -s 15
          }
          catch {
            _PrintError
          }
        }
      }
      # Enable CredSSP Server in remote nodes
      Write-Log "Enable CredSSP Server nodes on: $Global:Hostname"
      Enable-WSManCredSSP Server -Force
      # On all Nodes
      Write-ToReg $shares_already_created_reg
    }
}

function CreateTestDB {
    <#
    .SYNOPSIS
        Create a testDB
    .DESCRIPTION
        Creates a TestDB on the machines. Script based on:
         https://github.com/sqlthinker/dotnet-docs-samples/blob/master/compute/sqlserver/powershell/create-availability-group.ps1
    .EXAMPLE
        CreateTestDB
    #>

    $sql_data = "C:\$Script:db_folder_data"           # Directory to store the database data files
    $sql_log = "C:\$Script:db_folder_log"            # Directory to store the database transaction log files
    $data_size = 1024                   # Initial size of the database in MB
    $data_growth = 256                    # Auto growth size of the database in MB
    $log_size = 1024                   # Initial size of the transaction log in MB
    $log_growth = 256

    try {
      Write-Log "Disable Name Checking on $Global:hostname"
      Import-Module SQLPS -DisableNameChecking
      $objServer = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server `
       -ArgumentList 'localhost'
    }
    catch {
      _PrintError
      return $false
    }

    # Only continue if the database does not exist
    $objDB = $objServer.Databases[$Script:db_name]
    if (!($objDB)) {
      Write-Log "$Global:hostname - Creating the database $db_name"
      $objDB = New-Object `
       -TypeName Microsoft.SqlServer.Management.Smo.Database($objServer, $db_name)

      # Create the primary file group and add it to the database
      $objPrimaryFG = New-Object `
       -TypeName Microsoft.SqlServer.Management.Smo.Filegroup($objDB, 'PRIMARY')
      $objDB.Filegroups.Add($objPrimaryFG)

      # Create a single data file and add it to the Primary file group
      $dataFileName = $Script:db_name + '_Data'
      $objData = New-Object `
       -TypeName Microsoft.SqlServer.Management.Smo.DataFile($objPrimaryFG, $dataFileName)
      $objData.FileName = $sql_data + '\' + $dataFileName + '.mdf'
      $objData.Size = ($data_size * 1024)
      $objData.GrowthType = 'KB'
      $objData.Growth = ($data_growth * 1024)
      $objData.IsPrimaryFile = 'true'
      $objPrimaryFG.Files.Add($objData)

      # Create the log file and add it to the database
      $logName = $Script:db_name + '_Log'
      $objLog = New-Object Microsoft.SqlServer.Management.Smo.LogFile($objDB, $logName)
      $objLog.FileName = $sql_log + '\' + $logName + '.ldf'
      $objLog.Size = ($log_size * 1024)
      $objLog.GrowthType = 'KB'
      $objLog.Growth = ($log_growth * 1024)
      $objDB.LogFiles.Add($objLog)

      # Create the database
      $objDB.Script()  # Show a script with the command we are about to run
      $objDB.Create()  # Create the database
      $objDB.SetOwner('sa')  # Change the owner to sa
    }
    else {
      Write-Log "$Script:db_name DB already exists on $Global:hostname. Skipping ..."
    }
}

function InstallServerComponents {
    <#
    .SYNOPSIS
        Install all components needed for SQL Server Setup.
    .DESCRIPTION
        All install-windows feature and modules required on all nodes.
    .EXAMPLE
        InstallServerComponents
    #>

    Write-Log "Installing Server Components ..."
    try {
      # We may need to remove AD objects, so we will need the RSAT-AD-PowerShell
      Install-WindowsFeature RSAT-AD-PowerShell
      Install-WindowsFeature Failover-Clustering -IncludeManagementTools
      return $true
    }
    catch {
      Write-Log $_.Exception.GetType().FullName -error
      Write-Log "$_.Exception.Message"
      return $false
    }
}

function JoinDomain {
    <#
    .SYNOPSIS
        Join current machine to domain.
    .DESCRIPTION
        Attempts to join the  current machine domain
    .EXAMPLE
        JoinDomain
    #>

    Write-Log "Fetching Domain join parameters."

    <#Again, we are avoiding storing passwords in metadata#>
    $TempFile = New-TemporaryFile

    # invoke-command sees gsutil output as an error so redirect stderr to stdout and stringify to suppress
    gsutil cp $GcsPrefix/output/domain-admin-password.bin $TempFile.FullName 2>&1 | %{ "$_" }

    $DomainAdminPassword = $(gcloud kms decrypt --key $KmsKey --location $KmsRegion --keyring $Keyring --ciphertext-file $TempFile.FullName --plaintext-file - | ConvertTo-SecureString -AsPlainText -Force)

    Remove-Item $TempFile.FullName

    $clearPassword = Unwrap-SecureString $DomainAdminPassword
   
    $SA_PASSWORD = $clearPassword
 
    $credential = New-Object System.Management.Automation.PSCredential($script:domain_service_account, $SA_PASSWORD)
    Write-Log "Attempting to join $global:hostname to $Script:domain_name."
    try {
      Add-Computer -DomainName $Script:domain_name -Credential $credential
      return $true
    }
    catch {
      _PrintError
      return $false
    }
}

function SetIP{
    <#
    .SYNOPSIS
        Set local machine IP, Gateway and Firewall
    .DESCRIPTION
        Set IP address, Gateway, and Firewall
    .EXAMPLE
        SetIP
    #>

  Write-Log "Getting Current IP settings on $global:hostname."
  try {
    $current_ip = (Get-NetIPConfiguration | `
     Where InterfaceAlias -eq 'Ethernet').IPv4Address.IPAddress
    Write-Log "Current IP Address: $current_ip"

    $current_gateway = (Get-NetIPConfiguration | `
     Where InterfaceAlias -eq 'Ethernet').Ipv4DefaultGateway.NextHop
    Write-Log "Current GateWay Address: $current_gateway"
  }
  catch {
    _PrintError
    return $false
  }

  try {
    Write-Log "Setting Static IP on $global:hostname."
    _RunExternalCMD netsh interface ip set address name=Ethernet static $current_ip 255.255.0.0 $current_gateway 1

    Start-Sleep -Seconds 10

    Write-Log "Setting DNS $global:hostname."
    _RunExternalCMD netsh interface ip set dns Ethernet static 10.0.0.100

    Write-Log "Opening up SQL-Server specific Firewall ports $global:hostname."
    _RunExternalCMD netsh advfirewall firewall add rule `
     name="Open Port 5022 for Availability Groups" dir=in action=allow protocol=TCP localport=5022
    _RunExternalCMD netsh advfirewall firewall add rule `
     name="Open Port 1433 for SQL Server" dir=in action=allow protocol=TCP localport=1433
  }
  catch {
    _PrintError
    return $false
  }
  return $true
}

function SetScriptVar {
    <#
    .SYNOPSIS
        Initialize all necessary script variables.
    .DESCRIPTION
        Called once at the beginning of the script to initialize $Script:x
    .EXAMPLE
        SetScriptVar
    #>


    <# Here we need to make some changes. We dont want to have to pass in a use and password in metadata
    but rather get the encrypted password from GCS#>
    Write-Host "Getting job metadata in SetScriptVar..."
    $Domain = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/attributes/domain-name
    $NetBiosName = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/attributes/netbios-name
    $KmsKey = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/attributes/kms-key
    $KmsRegion = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/attributes/keyring-region
    $Region = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/attributes/region
    $Keyring = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/attributes/keyring
    $GcsPrefix = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/attributes/gcs-prefix
    
    Write-Host "Fetching admin credentials..."
    
    Write-Logger "Netbios name is $NetBiosName"

    # fetch domain admin credentials
    If ($GcsPrefix.EndsWith("/")) {
      $GcsPrefix = $GcsPrefix -Replace ".$"
    }
    $TempFile = New-TemporaryFile

    # invoke-command sees gsutil output as an error so redirect stderr to stdout and stringify to suppress
    gsutil cp $GcsPrefix/output/domain-admin-password.bin $TempFile.FullName 2>&1 | %{ "$_" }

    $DomainAdminPassword = $(gcloud kms decrypt --key $KmsKey --location $KmsRegion --keyring $Keyring --ciphertext-file $TempFile.FullName --plaintext-file - | ConvertTo-SecureString -AsPlainText -Force)

    Remove-Item $TempFile.FullName

    $clearPassword = Unwrap-SecureString $DomainAdminPassword
   
    $Script:service_account = "Administrator"
    $Script:domain_name = $Domain
    $Script:domain_bios_name = $NetBiosName
    $script:sa_password = $clearPassword
    
    # If the instance is allready on the domain dont try and add it again
    if((Get-WmiObject Win32_ComputerSystem).Domain -eq $Script:domain_name){
      Write-Logger "This instance is already on $script:domain_name"
      Write-ToReg "HKLM:\SOFTWARE\Google\SQLOnDomain"
    }

    # Set Service Account
    #$Script:service_account = _FetchFromMetaData -property 'attributes/c2d-property-sa-account'

    # Set DomainName Properties
    #$Script:domain_name = _FetchFromMetaData -property 'attributes/c2d-property-domain-dns-name'
    #$Script:domain_bios_name = $Script:domain_name.split(".")[0]
    $script:domain_service_account = "$Script:domain_bios_name\$Script:service_account"
  
    # Get all nodes
    $Script:all_nodes = ((_FetchFromMetaData -property 'attributes/sql_nodes').split("|")).Where({ $_ -ne "" })
    
    Write-Logger "Domain service account is  $script:domain_service_account"
    Write-Logger "All nodes: $Script:all_nodes"
    Write-Logger "domain_bios_name = $Script:domain_bios_name"

    # Add FQDN and get static ip address
    $ip_count = 1
    ForEach ($host_node in $all_nodes) {
     $Script:all_nodes_fqdn += "$host_node.$Script:domain_name"
     $Script:static_ip += "10.$ip_count.0.4"
     $Script:static_listner_ip += "10.$ip_count.0.5/255.255.0.0"
     $ip_count++
     if (!($host_node -eq $Global:hostname)) {
       $script:remote_nodes += "$($Script:domain_bios_name)\$($host_node)`$"
     }
    }

    $script:node2 = $all_nodes[1]
    
    Write-Logger "remote nodes: $script:remote_nodes"

    # Create PS CRED object
    $Pwd = ConvertTo-SecureString $script:sa_password -AsPlainText -Force
    $Script:cred_obj = New-Object System.Management.Automation.PSCredential $script:domain_service_account, $Pwd
}

function SetupCluster {
   <#
    .SYNOPSIS
        Setup New Cluster
    .DESCRIPTION
        Setups a new cluster and enables availability group
    .EXAMPLE
        SetupCluster
    #>
    $if_exists = $null
    $retry_attempt = $null
    $no_of_try =

    # This loop is to catch an edge case where _NewCluster setup exists
    # without any error message and does not setup cluster.
    for ($retry_attempt=0; $retry_attempt -le 1; $retry_attempt++) {
      if(_NewCluster) { # Run the setup command.
        try {
          $if_exists = (Get-Cluster -ErrorAction SilentlyContinue).Name
          if ($if_exists) {
            Write-Logger "-- $if_exists new cluster setup complete. --"
            break
          }
        }
        catch [System.Management.Automation.PropertyNotFoundException] {
          # This block will run if NewCluster ran without any errors.
          Write-Logger "## Cluster $Script:cluster_name is not configured. Will retry again, attempt: $retry_attempt .. ##"
          continue
        }
        catch {
          Write-Logger $_.Exception.GetType().FullName
          Write-Logger "$_.Exception.Message"
          return $false
        }
      }
      else { # if the NewCluster command fails exit
        Write-Logger "** NewCluster setup failed. **"
        return $false
      }
    }

    if($if_exists) {
      if(_EnableAlwaysOn){
        Write-Logger "-- Always on enabled for all nodes in cluster. --"
        return $true
      }
      else{
        Write-Logger "** Turning on AlwaysOn feature for nodes:$Script:all_nodes. **"
        return $false
      }
    }
    else{
      Write-Logger "** Cluster setup failed for unknown reason. **"
      return $false
    }
}

function UpdateSubWaiter {
   <#
    .SYNOPSIS
        UpdateSubWaiter
    .DESCRIPTION
        Updates sub runtime waiters.
    .EXAMPLE
        UpdateSubWaiter -key <keyname>
    #>
    param (
    [Alias('key')]
    [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        $key_path
    )
    Write-Logger "Updating subwaiter at key_path $key_path"
    $rtconfig = _GetRuntimeConfig
    Write-Logger "Runtime config is at $rtconfig"
    CreateRunTimeVariable -config_path $rtconfig -var_name "$key_path" /failure/failed
}


## Main

# Initialize Script variables
SetScriptVar

Write-Logger "Fnished setting vars"

# Set registry paths
$sql_on_domain_reg = "HKLM:\SOFTWARE\Google\SQLOnDomain"
$sql_configured_reg = "HKLM:\SOFTWARE\Google\SQLServerConfigured"
$sql_server_task = "HKLM:\SOFTWARE\Google\SQLServerTask"
$shares_already_created_reg = "HKLM:\SOFTWARE\Google\SharesCreated"

if($as_job){ # Run as Scheduled Task.
  if (Test-Path -path $sql_configured_reg) {
    Write-Logger "$global:hostname sql node is already configured. Nothing to do here."
    exit 0
  }

  # Lets create the cluster as a Scheduled task in the service account context
  Write-Logger "Attempting to install cluster on $Global:hostname"
  Write-Logger "-- Running as $env:UserName --"

  if (CheckIfNode1){ # This command runs on node1
    if (SetupCluster) {
      Write-Logger "Cluster setup was successful on $Global:hostname"
      Write-Logger "----------------------------"
      Write-Logger "SQL Cluster install finished on $Global:hostname."
      Write-Logger "----------------------------"
      UpdateSubWaiter -key "$Script:cluster_key_path/success/done"
    }
    else {
      Write-Logger "** SetupCluster step failed ***"
      UpdateSubWaiter -key "$Script:cluster_key_path/failure/failed"
      UpdateRunTimeWaiter -path status -failure
      exit
    }
  }
  else { # All Secondary nodes
    Write-Logger "Waiting for cluster setup."
    if ((WaitForRuntime -path "$Script:cluster_key_path/success/done" -timeout 10)){
      Write-Logger "Cluster Setup finished on primary node"
    }
    else {
      Write-Logger "** Something went wrong during primary cluster setup. **"
      UpdateRunTimeWaiter -path status -failure
      exit
    }
  }

  # Run this for all nodes
  if (ConfigureAvailabiltyGroup){
    # All Done
    Write-Logger "----------------------------"
    Write-Logger " AG install finished on $Global:hostname."
    Write-Logger "----------------------------"
    Write-ToReg $sql_configured_reg
    UpdateRunTimeWaiter -path status
    exit
  }
  else {
    Write-Logger "*** Failed to create Availability Group. ***"
    UpdateRunTimeWaiter -failure
    UpdateRunTimeWaiter -path status -failure
  }
}

Write-Log "We are live from SQL Server nodes."
# Set Static IP Address
if (SetIP) {
  UpdateRunTimeWaiter
}
else {
  UpdateRunTimeWaiter -failure
}

# Do SQL Server Installs
if (Test-Path -path $sql_on_domain_reg) {
  Write-Log "$global:hostname is already on domain $script:domain_name"
  # Check if first bootup. If yes, do following steps.
  Write-Log "$global:hostname sql node is joined to the $Script:domain_name domain." -important
 }
 else { # Join the machine to the domain
  # Write-Log "We are live from SQL Server nodes."
  # # Set Static IP Address
  # if (SetIP) {
  #   UpdateRunTimeWaiter
  # }
  # else {
  #   UpdateRunTimeWaiter -failure
  # }
  if (JoinDomain) {
    UpdateRunTimeWaiter
    # Create registry key so this block is not run again.
    Write-ToReg $sql_on_domain_reg

    Write-Log "Rebooting $global:hostname"
    Restart-Computer
    exit
  }
  else {
    UpdateRunTimeWaiter -failure
  }
}

# Configure SQL Server after domain join
if (Test-Path -path $sql_configured_reg) {
  Write-Log "$global:hostname sql node is already configured. Nothing to do here." -important
  exit 0
}
elseif ($task_name -and (!(Test-Path $sql_server_task ))) {
  Write-Log "Need to configure node for fail-over clustering."
  CreateShares
  InstallServerComponents
  Write-Log "Installed all necessary components"
  if (CheckIfNode1){ # Create TestDB on Node1
    Write-Log "Creating Local Database" -important
    CreateTestDB
  }

  # First Check if the scheduled task already exists?
  $sc_task = Get-ScheduledTask -TaskName $task_name -ErrorAction SilentlyContinue
  if ($sc_task) {
    Write-Log "-- $task_name scheduled task already exists. --"
  }
  else { # Create the scheduled task
    Write-Log "Create schtask: $task_name with file $PSCommandPath"
    CreateSCTask -name $task_name -user $script:domain_service_account -password $script:sa_password -file $PSCommandPath
    Start-Sleep -Seconds 5

    # Create registry key so this block is not run again
    Write-ToReg $sql_server_task

    Start-ScheduledTask -TaskName $task_name
    Write-Log "Scheduled task $task_name finished running."
  }
}
else {
  Write-Log "All SQL steps are done. For cluster setup run $PSCommandPath -AsJob"
}
