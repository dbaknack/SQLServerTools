if($null -eq (Get-Module -Name 'PSCONNECT')){
    lr;  Import-Module .\PSCONNECT

    $PSCONNECT_PARAMS = @{
        SourceFolderName 	= "$env:HOMEPATH\Documents\Knowledge_Base\Sources_Library\PSCONNECT-Data"
        SourceFileName		= "HOSTDATA.csv"
    }    

    #	Retrieve HostData:
    #	Note:
    #	entries in your file have a 'Enable' property
    #	when 'True' the host will be available to connect to
    #	when 'False' the host will not be avaible to connect to
    #	when the All parameter value is true, all entries regardless of the Enable value are returned
    #	when the All parameter value is false, only entries whos Enable value is true is returned
    $PSCONNECT.GetHostData(@{ALL = $false}) | Format-Table -Autosize
    
}else{
    Remove-Module PSCONNECT
    Write-Host "[PSCONNECT]:: Removed." -f Cyan
}

if($null -eq $myCreds){
    $PSCONNECT = PSCONNECT @PSCONNECT_PARAMS
    $myCreds = Get-Credential
    $PSCONNECT.StashCredentials(@{CredentialAlias = "NIPR-RES";Credentials = $myCreds})
    $PSCONNECT.CreateRemoteSession(@{use = "Hostname"}) 
}

$hostList = $PSCONNECT.GetHostData(@{ALL = $false}) | Select-Object "NamedInstance ",Enclave, HostName,InstanceName
$newHostList = @()
foreach($hostItem in $hostList){
    $newHostList += @{
        Enclave         = $hostItem.Enclave
        HostName        = $hostItem.HostName
        isNamedInstance = $hostItem."NamedInstance "
        InstanceName    = $hostItem.InstanceName
        CheckConfig     =@{
            DocumentationList = @{
                p1 = @(
                    "The table reveals that various features within the SQL Server instance on $($ENCLAVE) are disabled for security reasons."
                    "Each property is marked as not approved for use, indicating a cautious approach towards mitigating potential vulnerabilities."
                    "Disabling these features aligns with security best practices to reduce the risk of unauthorized access and data breaches."
                )
            }
            fromThisFolder      = ".\Remediation\"
            givenTheseFindings  = @(
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
            checkThisInstance   = @{instanceName = $hostItem.InstanceName;databaseName = "Master"}
            Results = @()
        }
        CheckRegistryPermissions = @{
            DocumentationList = @{
                p1 = @(
                    "This section of the technical documentation outlines a group of registry-related extended stored procedures available within Microsoft SQL Server."
                    "These procedures offer functionalities for managing Windows registry operations, such as adding, deleting, and enumerating"
                    "registry keys and values. It's important to note that these procedures are not enabled by default unless specifically required."
                )
            }
            fromThisFolder      = ".\Remediation\"
            givenTheseFindings  = @(
                [pscustomobject]@{id = "V-214033" ; Description = "Get edit registry permissions."}
            )
            checkThisInstance   = @{instanceName = $hostItem.InstanceName;databaseName = "Master"}
            Results = @()
        }
        CheckStoredProcedures = @{
            DocumentationList = @{
                p1 = @(
                    "In certain situations, to provide required functionality, a DBMS needs to execute internal logic (stored procedures, functions, triggers, etc.)"
                    "and/or external code modules with elevated privileges. However, if the privileges required for execution are at a higher level than the "
                    "privileges assigned to organizational users invoking the functionality applications/programs, those users are indirectly provided with greater "
                    "privileges than assigned by organizations."
                )
            }
            fromThisFolder      = ".\Remediation\"
            givenTheseFindings  = @(
                [pscustomobject]@{id = "V-214030" ; Description = "List of documented stored procedures."}
            )
            checkThisInstance   = @{instanceName = $hostItem.InstanceName;databaseName = "Master"}
            Results = @()
        }
        CheckInstalledFeatures = @{
            DocumentationList = @{
                p1 = @(
                    "Some DBMSs' installation tools may remove older versions of software automatically from the information system. In other cases, manual review "
                    "and removal will be required. In planning installations and upgrades, organizations must include steps (automated, manual, or both) to "
                    "identify and remove the outdated modules. "
                )
            }
            fromThisFolder      = ".\Remediation\"
            givenTheseFindings  = @(
                [pscustomobject]@{id = "V-213993" ; Description = "List the installed features"}
            )
            Results = @()
        }
    }
}

# CHECK: configuration
foreach($instance in $newHostList){
    
    $instanceName = $instance.HostName
    $databaseName = $instance.CheckConfig.checkThisInstance.databaseName
    if($instance.isNamedInstance -eq 'true'){
        $instanceName = "{0}\{1}" -f $instance.HostName,$instance.InstanceName
    }
    Write-Host "[CHECK: configuration] - HostName: $($instance.HostName) - InstanceName: $instanceName" -ForegroundColor Cyan
    foreach($finding in $instance.CheckConfig.givenTheseFindings){
        $scriptFolder   =   ("{0}{1}\" -f $instance.CheckConfig.fromThisFolder,$finding.id)
        $scriptFile     =   (Get-ChildItem -Path $scriptFolder).BaseName
        $instance.CheckConfig.Results      +=  (Invoke-PSSQL @{
            Session             =   Get-PSSession -Name $instance.HostName
            SQLScriptFolder     =   $scriptFolder 
            SQLScriptFile       =   $scriptFile
            ConnectionParams    =   @{
                InstanceName    =   $instanceName 
                DatabaseName    =   $databaseName 
            }
        }).rows
    }
}

# CHECK: Registry Permissions
foreach($instance in $newHostList){
    
    $instanceName = $instance.HostName
    $databaseName = $instance.CheckRegistryPermissions.checkThisInstance.databaseName
    if($instance.isNamedInstance -eq 'true'){
        $instanceName = "{0}\{1}" -f $instance.HostName,$instance.InstanceName
    }
    Write-Host "[CHECK: Registry Permissions] - HostName: $($instance.HostName) - InstanceName: $instanceName" -ForegroundColor Cyan

    foreach($finding in $instance.CheckRegistryPermissions.givenTheseFindings){
        $scriptFolder   =   ("{0}{1}\" -f $instance.CheckRegistryPermissions.fromThisFolder,$finding.id)
        $scriptFile     =   (Get-ChildItem -Path $scriptFolder).BaseName
        $instance.CheckRegistryPermissions.Results +=  (Invoke-PSSQL @{
            Session             =   Get-PSSession -Name $instance.HostName
            SQLScriptFolder     =   $scriptFolder 
            SQLScriptFile       =   $scriptFile
            ConnectionParams    =   @{
                InstanceName    =   $instanceName 
                DatabaseName    =   $databaseName 
            }
        }).rows
    }
}

# CHECK : CheckStoredProcedures
foreach($instance in $newHostList){
    
    $instanceName = $instance.HostName
    $databaseName = $instance.CheckStoredProcedures.checkThisInstance.databaseName
    if($instance.isNamedInstance -eq 'true'){
        $instanceName = "{0}\{1}" -f $instance.HostName,$instance.InstanceName
    }
    Write-Host "[CHECK : CheckStoredProcedures] - HostName: $($instance.HostName) - InstanceName: $instanceName" -ForegroundColor Cyan

    foreach($finding in $instance.CheckStoredProcedures.givenTheseFindings){
        $scriptFolder   =   ("{0}{1}\" -f $instance.CheckStoredProcedures.fromThisFolder,$finding.id)
        $scriptFile     =   (Get-ChildItem -Path $scriptFolder).BaseName
        $instance.CheckStoredProcedures.Results +=  (Invoke-PSSQL @{
            Session             =   Get-PSSession -Name $instance.HostName
            SQLScriptFolder     =   $scriptFolder 
            SQLScriptFile       =   $scriptFile
            ConnectionParams    =   @{
                InstanceName    =   $instanceName 
                DatabaseName    =   $databaseName 
            }
        }).rows
    }
}

# CHECK : Installed Features
foreach($instance in $newHostList){
    $instanceName = $instance.HostName
    $databaseName = $instance.CheckInstalledFeatures.checkThisInstance.databaseName
    if($instance.isNamedInstance -eq 'true'){
        $instanceName = "{0}\{1}" -f $instance.HostName,$instance.InstanceName
    }

    Write-Host "[CHECK : Installed Features] - HostName: $($instance.HostName) - InstanceName: $instanceName" -ForegroundColor Cyan

    foreach($finding in $instance.CheckInstalledFeatures.givenTheseFindings){
        $scriptFolder   =   ("{0}{1}\" -f $instance.CheckInstalledFeatures.fromThisFolder,$finding.id)
        $scriptFile     =   (Get-ChildItem -Path $scriptFolder).BaseName
        $instance.CheckInstalledFeatures.Results +=  (Invoke-PSCMD @{
            Session                 = @(Get-PSSession -Name $instance.HostName)
            PowerShellScriptFolder  = $scriptFolder
            PowerShellScriptFile    = $scriptFile
            ArgumentList            = @($instance)
            AsJob                   = $false
        })
    }
}
#$instance.CheckInstalledFeatures.Results  = $instance.CheckInstalledFeatures.Results | 
#Select-Object -Property * -ExcludeProperty @("PSComputerName","RunspaceId")


$newHostList.CheckConfig.Results | ft -a   
$newHostList.CheckRegistryPermissions.Results | ft -a  
$newHostList.CheckStoredProcedures.Results | ft -a
$newHostList.CheckInstalledFeatures.Results | ft -a

# here we pass is a session, but not as a job
$results = Invoke-PSCMD @{
    Session                 = @(Get-PSSession -Name $instance.HostName)
    PowerShellScriptFolder  = $scriptFolder
    PowerShellScriptFile    = $scriptFile
    ArgumentList            = @($instance)
    AsJob                   = $false
};$results

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
foreach($instance in $newHostList){
    if(-not($instance.isNamedInstance)){
        $registry_instance_ref = "MSSQLSERVER"
    }else{
        $registry_instance_ref = $instance.InstanceName
    }
    try{
        Set-Location -path "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\" -ErrorAction Stop
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

RESTORE VERIFYONLY FROM DISK = '<backup_device>'
