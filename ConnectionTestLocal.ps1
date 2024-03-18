$REMEDITION_FOLDER  = ".\SQLServerTools\Remediation\"
$FINDINGS_TABLE     = @(
    [pscustomobject]@{id = "V-214043" ; Description = "Get replication xp configuration."}
    [pscustomobject]@{id = "V-214041" ; Description = "Get external script configuration."}
    [pscustomobject]@{id = "V-214040" ; Description = "Get remote data archive configuration."}
    [pscustomobject]@{id = "V-214039" ; Description = "Get polybase configuration."}
    [pscustomobject]@{id = "V-214038" ; Description = "Get hadoop configuration."}
    [pscustomobject]@{id = "V-214037" ; Description = "Get remote connectivity configuration."}
    [pscustomobject]@{id = "V-214036" ; Description = "Get user options configuration."}
    [pscustomobject]@{id = "V-214035" ; Description = "Get ole automation procedures configuration."}
    [pscustomobject]@{id = "V-214034" ; Description = "Get file stream configuration."}
)


$PARAMS = @{
    fromThisFolder      = $REMEDITION_FOLDER
    givenTheseFindings  = $FINDINGS_TABLE
    checkThisInstance   = @{instanceName = ".";databaseName = "Master"}
}
Function CompileResults {
    param([hashtable]$fromSender)
    begin{
        $invokeUDFSQLCommandParams = @{
            Instance        = $fromSender.CheckThisInstance.InstanceName
            DatabaseName    = $fromSender.CheckThisInstance.DatabaseName
            Query           = ''
        }
        $commandResults = @()
    }
    process{
        foreach($finding in $fromSender.GivenTheseFindings){
            try{
                $scriptFile = Get-ChildItem -Path ("{0}{1}\" -f $fromSender.FromThisFolder,$finding.id) -Filter "*.sql"
            }catch{
                $error[0]
            }
            try{
                $command = (Get-Content -Path $scriptFile.FullName) -join "`n"
            }catch{
                $error[0]
            }
            $invokeUDFSQLCommandParams.Query = $command
            $commandResults += Invoke-UDFSQLCommand $invokeUDFSQLCommandParams
        }
    }
    end{
        $totalEntries = ($commandResults.count) - 1
        $cntr = 1
        foreach($entry in 0..$totalEntries){
            $commandResults[$entry].RecID = $cntr
            $cntr++
        }
        return $commandResults
    }
}
Function Get-SqlInstances{

    Param($ServerName = [System.Net.Dns]::GetHostName())
   
 
    $LocalInstances = @()
 
    [array]$Captions = Get-WmiObject win32_service -ComputerName $ServerName |
      Where-Object {
        $_.Name -match "mssql*" -and
        $_.PathName -match "sqlservr.exe"
      } |
        ForEach-Object {$_.Caption}
 
    foreach ($Caption in $Captions) {
      if ($Caption -eq "MSSQLSERVER") {
        $LocalInstances += "MSSQLSERVER"
      } else {
        $Temp = $Caption |
          ForEach-Object {$_.split(" ")[-1]} |
          ForEach-Object {$_.trimStart("(")} |
            ForEach-Object {$_.trimEnd(")")}
 
        $LocalInstances += "$ServerName\$Temp"
      }
 
    }
 
     $instance_names_list = @()
     $instance_ruid = 1
    foreach($localinstance_name in $LocalInstances){
      # if the instance name is not a named instance, this condition will be true
      if($localinstance_name -match '(.*)\\(MSSQLSERVER)'){
         $instance_names_list += [pscustomobject]@{
          id = $instance_ruid
          host_name = $ServerName
          instance_type = 'unnamed'
          instance_name = $matches[1]
          }
      }else{
          $instance_names_list += [pscustomobject]@{
              id = $instance_ruid
              host_name = $ServerName
              instance_type = 'named'
              instance_name =  $localinstance_name
          }
      }
      $instance_ruid = $instance_ruid + 1
    }
    $instance_names_list | Group-Object -Property host_name -AsHashTable
}
$ENCLAVE = "DEVLAPTOP"
$p = @(
    "The table reveals that various features within the SQL Server instance on $($ENCLAVE) are disabled for security reasons."
    "Each property is marked as not approved for use, indicating a cautious approach towards mitigating potential vulnerabilities."
    "Disabling these features aligns with security best practices to reduce the risk of unauthorized access and data breaches."
)
$ResultSet = CompileResults $PARAMS
$ResultSet | Format-Table -AutoSize


$PARAMS = @{
    fromThisFolder      = $REMEDITION_FOLDER
    givenTheseFindings  = @(
        [pscustomobject]@{id = "V-214033" ; Description = "Get edit registry permissions."}
    )
    checkThisInstance   = @{instanceName = ".";databaseName = "Master"}
}

$p = @(
    "This section of the technical documentation outlines a group of registry-related extended stored procedures available within Microsoft SQL Server."
    "These procedures offer functionalities for managing Windows registry operations, such as adding, deleting, and enumerating"
    "registry keys and values. It's important to note that these procedures are not enabled by default unless specifically required."
)
$ResultSet = CompileResults $PARAMS
$ResultSet | Format-Table -AutoSize


$Instances          = Get-SqlInstances
$sqlRegistryPath    = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\"
$registryPaths      = @{
    CPE = @{
        RelativePath    = ".\CPE"
        Description     = @(
            "The settings under this key typically include configuration details that affect the SQL Server instances operation,"
            "possibly including licensing information, version details, or configuration flags specific to"
            "how SQL Server should operate on the system."
        )
    }
    MSSQLSERVER = @{
        RelativePath    = ".\MSSQLSERVER"
        Description     = @(
            "Under this registry key, you'll find a variety of subkeys and values that manage different aspects of the SQL Server" 
            "instance, such as security, network configuration, database settings, and more."
        )
    }
    SETUP = @{
        RelativePath    = ".\SETUP"
        Description = @(
            "This key contains information specifically related to the setup and configuration of the SQL Server instance."
            "It might include data such as the path to the SQL Server binaries"
        )
    }
    SQLServerAgent = @{
        RelativePath    = ".\SQLServerAgent"
        Description = @(
            "Configuration options under this key might include settings related to job execution, logging, and the service"
            "account under which the SQL Server Agent operates."
        )
    }
}
foreach($instance in $Instances){
    if($instance.values.instance_type -eq 'unnamed'){
        $registry_instance_ref = "MSSQLSERVER"
    }else{
        $registry_instance_ref = $instance.values.instance_name
    }

    try{
        Set-Location -path $sqlRegistryPath -ErrorAction Stop
    }catch{
        $error[0]
    }
    
    $sqlLvl1Path = Get-ChildItem | Where-Object {$_.name -like "*MSSQL*$($registry_instance_ref)"}
    
    try{
        Set-Location -path  ".\$((($sqlLvl1Path.name) -split "\\")[-1])"
    }catch{
        $error[0]
    }
    $CurrentPath = Get-Location
    foreach($path in $registryPaths.keys){
        Set-Location -path ($registryPaths.$path.RelativePath)
        $locationProperties = Get-ItemProperty -Path .
        
        switch($path){
            "CPE" {
                $registryPaths.$path.Add("Properties",@{})
                $registryPaths.$path.Properties = @{
                    ErrorDumpDir = $locationProperties.ErrorDumpDir
                }
                
            }
            "MSSQLServer"{
                $registryPaths.$path.Add("Properties",@{})
                $registryPaths.$path.Properties = @{
                    BackupDirectory = $locationProperties.BackupDirectory
                }
            }
            "SETUP"{
                $registryPaths.$path.Add("Properties",@{})
                $registryPaths.$path.Properties = @{
                    SQLPath         = $locationProperties.SQLPath
                    SqlProgramDir   = $locationProperties.SqlProgramDir
                    SQLBinRoot      = $locationProperties.SQLBinRoot
                    FeatureList     = @()
                }
                $featureListValues = $locationProperties.FeatureList -split (' ')
                foreach($feature in $featureListValues){
                    $prop           = $feature -split ('=')
                    $featureName    = $prop[0]
                    $stateDescription = switch($prop[-1]){
                        0 {"Feature is not installed."}
                        1 {"Installed but disabled."}
                        2 {"Installd in a pending state."}
                        3 {"Installed and fully operational."}
                        default {"Feature state is unknown."}
                    }
                    $registryPaths.$path.Properties.FeatureList +=[pscustomobject]@{
                        Feature             = $featureName
                        FeatureStateValue   = $prop[-1]
                        StateDescription    = $stateDescription
                    }
                }
            }
            "SQLServerAgent"{
                $registryPaths.$path.Add("Properties",@{})
                $registryPaths.$path.Properties = @{
                    ErrorLogFile        = $locationProperties.ErrorLogFile
                    WorkingDirectory    = $locationProperties.WorkingDirectory
                }
            }
        }
        Set-Location $CurrentPath
    }    
}

$sqlBin = $registryPaths.SETUP.Properties.SQLBinRoot
$aclTable = @()
foreach($authA in ((Get-Acl $sqlBin).Access)){
    $aclTable += [pscustomobject]@{
        FolderPath          = $sqlBin
        Account             = $authA.IdentityReference.value
        AccessControlType   = $authA.AccessControlType
        IsInherited         = $authA.IsInherited
        PropagationFlags    = $authA.PropagationFlags
        Rights              = $authA.FileSystemRights 
        InheritanceFlags    = $authA.InheritanceFlags
    }   
}
$aclTable | select @('Account','Rights','PropagationFlags','AccessControlType','InheritanceFlags') | ft -a


# Define the path
$path = "C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\Binn"

# Get the current ACL
$acl = Get-Acl $path

$accountGroup = $aclTable | Group-Object -Property 'Account' -AsHashTable

# Find and remove the specific access rules for BUILTIN\Users
$acl.Access | Where-Object { $_.IdentityReference -eq "BUILTIN\Users" } | ForEach-Object { $acl.RemoveAccessRule($_) }
Set-Acl -Path $path -AclObject $acl


NT AUTHORITY\SYSTEM (FullControl)
Why? This is a highly privileged system account with extensive permissions to the system. Granting it Full Control 
is standard because many Windows services run under this account and may require extensive access to function correctly, 
including SQL Server components.

CREATOR OWNER (FullControl)
Why? This special placeholder account allows the user who created a file or directory to have Full Control over it. In the 
context of SQL Server, this ensures that files or directories created by SQL Server processes can be managed appropriately. 
However, this is more relevant for user data and log directories than for the Binn directory. You might want to limit this 
for Binn specifically if your security policy dictates.

BUILTIN\Administrators (FullControl)
Why? Members of the local Administrators group should have Full Control to manage and configure SQL Server. This includes 
installing updates, changing configurations, and managing security settings.

BUILTIN\Users (ReadAndExecute, Synchronize)
Why? This allows regular authenticated users to read and execute files but not modify them. For the Binn directory, which 
contains executable files for SQL Server, this might be unnecessarily permissive. You may want to restrict this further to 
prevent regular users from executing SQL Server binaries directly. Usually, only service accounts and administrators need 
access to these files.

NT SERVICE\MSSQLSERVER (ReadAndExecute, Synchronize)
Why? This is the service account under which the SQL Server instance runs. Granting it ReadAndExecute allows it to read and 
execute necessary binaries and scripts for SQL Server to operate. However, depending on your SQL Server setup, this account 
might require more permissions, potentially even Full Control, if it's responsible for managing updates or configurations within 
the Binn directory.