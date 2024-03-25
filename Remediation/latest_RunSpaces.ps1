if($null -eq (Get-Module -Name 'PSCONNECT')){
    lr;  Import-Module .\PSCONNECT
    $PSCONNECT_PARAMS = @{
        SourceFolderName 	= "$env:HOMEPATH\Documents\Knowledge_Base\Sources_Library\PSCONNECT-Data"
        SourceFileName		= "HOSTDATA.csv"
    }      
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


$newHostList    = @()
foreach($hostItem in $PSCONNECT.GetHostData(@{ALL = $false})){
    $newHostList += @{
        Enclave                 = $hostItem.Enclave
        Alias                   = $hostItem.Alias
        HostName                = $hostItem.HostName
        IsNamedInstance         = $hostItem."NamedInstance"
        InstanceName            = $hostItem.InstanceName
        ListenerName            = $hostItem.ListenerName
        ConnectionPreference    = $hostItem.ConnectionPreference
        ListenerIP              = $hostItem.ListenerIP
        ListenerPort            = $hostItem.ListenerPort

        # Check parameters ---------------
        CheckConfig                         = @{
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
        CheckRegistryPermissions            = @{
            DocumentationList = @{
                p1 = @(
                    "This section of the technical documentation outlines a group of registry-related extended stored procedures available within MicrosoFormat-Table -Autosize SQL Server."
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
        CheckStoredProcedures               = @{
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
        CheckInstalledFeatures              = @{
            DocumentationList = @{
                p1 = @(
                    "Some DBMSs' installation tools may remove older versions of soFormat-Table -Autosizeware automatically from the information system. In other cases, manual review "
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
        CheckSQLServerBinaryPermissions     = @{
            DocumentationList = @{
                p1 = @(
                    "The following group and permissions are documented:"
                    ""
                    "NT AUTHORITY\SYSTEM (FullControl)"
                    "CREATOR OWNER (FullControl)"
                    "BUILTIN\Administrators (FullControl)"
                    "BUILTIN\Users (ReadAndExecute, Synchronize)"
                    "NT SERVICE\MSSQLSERVER (ReadAndExecute, Synchronize)"
                    "NT AUTHORITY\SYSTEM (FullControl)"
                    ""
                    "This is a highly privileged system account with extensive permissions to the system. Granting it Full Control "
                    "is standard because many Windows services run under this account and may require extensive access to function correctly, "
                    "including SQL Server components."
                    ""
                    "CREATOR OWNER (FullControl)"
                    "This special placeholder account allows the user who created a file or directory to have Full Control over it. In the "
                    "context of SQL Server, this ensures that files or directories created by SQL Server processes can be managed appropriately. "
                    "However, this is more relevant for user data and log directories than for the Binn directory. You might want to limit this "
                    "for Binn specifically if your security policy dictates."
                    ""
                    "BUILTIN\Administrators (FullControl)"
                    "Members of the local Administrators group should have Full Control to manage and configure SQL Server. This includes "
                    "installing updates, changing configurations, and managing security settings."
                    ""
                    "BUILTIN\Users (ReadAndExecute, Synchronize)"
                    "This allows regular authenticated users to read and execute files but not modify them. For the Binn directory, which "
                    "contains executable files for SQL Server, this might be unnecessarily permissive. You may want to restrict this further to "
                    "prevent regular users from executing SQL Server binaries directly. Usually, only service accounts and administrators need "
                    "access to these files."
                    ""
                    "NT SERVICE\MSSQLSERVER (ReadAndExecute, Synchronize)"
                    "WThis is the service account under which the SQL Server instance runs. Granting it ReadAndExecute allows it to read and "
                    "execute necessary binaries and scripts for SQL Server to operate. However, depending on your SQL Server setup, this account "
                    "might require more permissions, potentially even Full Control, if it's responsible for managing updates or configurations within "
                    "the Binn directory."
                )
            }
            fromThisFolder      = ".\Remediation\"
            givenTheseFindings  = @(
                [pscustomobject]@{id = "V-213950" ; Description = "List the SQL Server binary permissions."}
            )
            Results = @()
        }
        CheckSQLLoginPermissions            = @{
            DocumentationList = @{
                p1 = @(
                    "SQL Server must enforce approved authorizations for logical access to information and system resources in accordance with applicable access control policies."
                    "In this section, all the instance logins and ther documentated permissions:"
                )
            }
            fromThisFolder      = ".\Remediation\"
            givenTheseFindings  = @(
                [pscustomobject]@{id = "V-213932" ; Description = "List the SQL Server Logins and descriptions."}
            )
            Results = @()
        }
        CheckSQLLoginDescriptions           = @{
            DocumentationList = @{
                p1 = @(
                    "SQL Server must enforce approved authorizations for logical access to information and system resources in accordance with applicable access control policies."
                    "In this section, all the instance logins and ther documentated permissions:"
                )
            }
            fromThisFolder      = ".\Remediation\"
            givenTheseFindings  = @(
                [pscustomobject]@{id = "V-213933" ; Description = "List the SQL Server Logins and descriptions."}
            )
            Results = @()
        }
        CheckSQLServerInstallDirectory      = @{
            DocumentationList = @{
                p1 = @(
                    "Database software, including DBMS configuration files, must be stored in dedicated directories, separate from the host OS and other applications.."
                )
            }
            fromThisFolder      = ".\Remediation\"
            givenTheseFindings  = @(
                [pscustomobject]@{id = "V-213953" ; Description = "Get SQL Server installation path."}
            )
            Results = @()
        }
        GetSQLServerBinnFileHash            = @{
            DocumentationList = @{
                p1 = @(
                    "The purpose of hash values is to provide a cryptographically-secure way to verify that the contents of a file have not been changed. While some hash algorithms,"
                    "including MD5 and SHA1, are no longer considered secure against attack, the goal of a secure hash algorithm is to render it impossible to change the contents of a "
                    "file -- either by accident, or by malicious or unauthorized attempt -- and maintain the same hash value. You can also use hash values to determine if two different "
                    "files have exactly the same content. If the hash values of two files are identical, the contents of the files are also identical."
                )
            }
            fromThisFolder      = ".\Remediation\"
            givenTheseFindings  = @(
                [pscustomobject]@{id = "V-213951" ; Description = "Get SQL Server binn hash."}
            )
            Results = @()
        }
        GetSQLInstallationAccounts          = @{
            DocumentationList = @{
                p1 = @(
                    "DBA and other privileged administrative or application owner accounts are granted privileges that allow actions that can have a great impact on SQL Server"
                    "security and operation. It is especially important to grant privileged access to only those persons who are qualified and authorized to use them."
                )
            }
            fromThisFolder      = ".\Remediation\"
            givenTheseFindings  = @(
                [pscustomobject]@{id = "V-213952" ; Description = "Get SQL Server installation accounts."}
            )
            Results = @()
        }
    }
}


# CHECK: configuration
foreach($instance in $newHostList){
    $endPoint = switch($instance.ConnectionPreference){
        "LIP+P" {
            #"{0},{1}"-f $instance.ListenerIP,$instance.ListenerPort
            "{0}\{1}" -f $instance.HostName,$instance.InstanceName
            break
        }
        "LN" {
            #"{0}"-f $instance.ListenerName
            "{0}\{1}" -f $instance.HostName,$instance.InstanceName
            break
        }
        "HN" {
            "{0}" -f $instance.HostName
            break
        }
        "IN" {
            "{0}\{1}" -f $instance.HostName,$instance.InstanceName
            break
        }
    }


    Write-Host "[CHECK: configuration] - HostName: $($instance.HostName) - EndPoint: $endPoint" -ForegroundColor Cyan

    foreach($finding in $instance.CheckConfig.givenTheseFindings){
        $scriptFolder   =   ("{0}{1}\" -f $instance.CheckConfig.fromThisFolder,$finding.id)
        $scriptFile     =   (Get-ChildItem -Path $scriptFolder).BaseName
        $instance.CheckConfig.Results      +=  (Invoke-PSSQL @{
            Session             =   (Get-PSSession -Name $instance.HostName)
            SQLScriptFolder     =   $scriptFolder 
            SQLScriptFile       =   $scriptFile
            ConnectionParams    =   @{
                InstanceName    =   $endPoint
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
    if($instance.HostName -eq $instance.InstanceName){
        $endPoint = $instance.HostName
    }else{
        if($instanceName.ConnectionPreference -eq "IN"){
            $endPoint = "{0}\{1}" -f $instance.HostName,$instance.InstanceName
        }
        if($instance.HostName -eq ($instance.alias -split '_')[0]){
            $endPoint = "{0}\{1}" -f $instance.HostName,$instance.InstanceName
        }
    }


    if($null -ne $endPoint){
        $databaseName = $instance.CheckStoredProcedures.checkThisInstance.databaseName
        Write-Host "[CHECK : CheckStoredProcedures] - HostName: $($instance.HostName) - InstanceName: $endPoint" -ForegroundColor Cyan
    
        foreach($finding in $instance.CheckStoredProcedures.givenTheseFindings){
            $scriptFolder   =   ("{0}{1}\" -f $instance.CheckStoredProcedures.fromThisFolder,$finding.id)
            $scriptFile     =   (Get-ChildItem -Path $scriptFolder).BaseName
            $instance.CheckStoredProcedures.Results +=  (Invoke-PSSQL @{
                Session             =   Get-PSSession -Name $instance.HostName
                SQLScriptFolder     =   $scriptFolder 
                SQLScriptFile       =   $scriptFile
                ConnectionParams    =   @{
                    InstanceName    =   $endPoint 
                    DatabaseName    =   $databaseName 
                }
            }).rows
        }
    }
    else{
        Write-Host "[CHECK : CheckStoredProcedures] - HostName: $($instance.HostName) - InstanceName: $endPoint Skipped..." -ForegroundColor Cyan
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

# CHECK : SQL Server Bin Permissions
foreach($instance in $newHostList){
    $instanceName = $instance.HostName
    $databaseName = $instance.CheckSQLServerBinaryPermissions.checkThisInstance.databaseName
    if($instance.isNamedInstance -eq 'true'){
        $instanceName = "{0}\{1}" -f $instance.HostName,$instance.InstanceName
    }

    Write-Host "[CHECK : SQL Server Binary Permissions] - HostName: $($instance.HostName) - InstanceName: $instanceName" -ForegroundColor Cyan

    foreach($finding in $instance.CheckSQLServerBinaryPermissions.givenTheseFindings){
        $scriptFolder   =   ("{0}{1}\" -f $instance.CheckSQLServerBinaryPermissions.fromThisFolder,$finding.id)
        $scriptFile     =   (Get-ChildItem -Path $scriptFolder).BaseName
        $recId          = 0
        foreach($entry in (Invoke-PSCMD @{
            Session                 = @(Get-PSSession -Name $instance.HostName)
            PowerShellScriptFolder  = $scriptFolder
            PowerShellScriptFile    = $scriptFile
            ArgumentList            = @($instance)
            AsJob                   = $false
        })){
            $instance.CheckSQLServerBinaryPermissions.Results += [pscustomobject]@{
                RecID   = $recId++
                HostName = $instance.HostName
                InstanceName = $instanceName
                FolderPath = $entry.FolderPath
                Account = $entry.Account
                Access = $entry.AccessControlType
                IsInherited = $entry.IsInherited
                PropagationFlags = $entry.PropagationFlags
                Rights = $entry.Rights
                InheritanceFlags = $entry.InheritanceFlags
            }
        }
        
    }
}

# CHECK : SQL Login Permissions
foreach($instance in $newHostList){
    if($instance.HostName -eq $instance.InstanceName){
        $endPoint = $instance.HostName
    }else{
        if($instanceName.ConnectionPreference -eq "IN"){
            $endPoint = "{0}\{1}" -f $instance.HostName,$instance.InstanceName
        }
        if($instance.HostName -eq ($instance.alias -split '_')[0]){
            $endPoint = "{0}\{1}" -f $instance.HostName,$instance.InstanceName
        }
    }


    if($null -ne $endPoint){
        $databaseName = $instance.CheckSQLLoginPermissions.checkThisInstance.databaseName
        Write-Host "[CHECK : CheckSQLLoginPermissions] - HostName: $($instance.HostName) - InstanceName: $endPoint" -ForegroundColor Cyan
    
        foreach($finding in $instance.CheckSQLLoginPermissions.givenTheseFindings){
            $scriptFolder   =   ("{0}{1}\" -f $instance.CheckSQLLoginPermissions.fromThisFolder,$finding.id)
            $scriptFile     =   (Get-ChildItem -Path $scriptFolder).BaseName
            $instance.CheckSQLLoginPermissions.Results +=  (Invoke-PSSQL @{
                Session             =   Get-PSSession -Name $instance.HostName
                SQLScriptFolder     =   $scriptFolder 
                SQLScriptFile       =   $scriptFile
                ConnectionParams    =   @{
                    InstanceName    =   $endPoint 
                    DatabaseName    =   $databaseName 
                }
            }).rows
        }
    }
    else{
        Write-Host "[CHECK : CheckStoredProcedures] - HostName: $($instance.HostName) - InstanceName: $endPoint Skipped..." -ForegroundColor Cyan
    }
}
# CHECK : SQL Login Descriptions
foreach($instance in $newHostList){
    if($instance.HostName -eq $instance.InstanceName){
        $endPoint = $instance.HostName
    }else{
        if($instanceName.ConnectionPreference -eq "IN"){
            $endPoint = "{0}\{1}" -f $instance.HostName,$instance.InstanceName
        }
        if($instance.HostName -eq ($instance.alias -split '_')[0]){
            $endPoint = "{0}\{1}" -f $instance.HostName,$instance.InstanceName
        }
    }


    if($null -ne $endPoint){
        $databaseName = $instance.CheckSQLLoginDescriptions.checkThisInstance.databaseName
        Write-Host "[CHECK : CheckSQLLoginDescriptions] - HostName: $($instance.HostName) - InstanceName: $endPoint" -ForegroundColor Cyan
    
        foreach($finding in $instance.CheckSQLLoginDescriptions.givenTheseFindings){
            $scriptFolder   =   ("{0}{1}\" -f $instance.CheckSQLLoginDescriptions.fromThisFolder,$finding.id)
            $scriptFile     =   (Get-ChildItem -Path $scriptFolder).BaseName
            $instance.CheckSQLLoginDescriptions.Results +=  (Invoke-PSSQL @{
                Session             =   Get-PSSession -Name $instance.HostName
                SQLScriptFolder     =   $scriptFolder 
                SQLScriptFile       =   $scriptFile
                ConnectionParams    =   @{
                    InstanceName    =   $endPoint 
                    DatabaseName    =   $databaseName 
                }
            }).rows
        }
    }
    else{
        Write-Host "[CHECK : CheckStoredProcedures] - HostName: $($instance.HostName) - InstanceName: $endPoint Skipped..." -ForegroundColor Cyan
    }
}

# CHECK: SQL Server Install Location
foreach($instance in $newHostList){
    $instanceName = $instance.HostName
    $databaseName = $instance.CheckSQLServerInstallDirectory.checkThisInstance.databaseName
    if($instance.isNamedInstance -eq 'true'){
        $instanceName = "{0}\{1}" -f $instance.HostName,$instance.InstanceName
    }

    Write-Host "[CHECK : CheckSQLServerInstallDirectory] - HostName: $($instance.HostName) - InstanceName: $instanceName" -ForegroundColor Cyan

    foreach($finding in $instance.CheckSQLServerInstallDirectory.givenTheseFindings){
        $scriptFolder   =   ("{0}{1}\" -f $instance.CheckSQLServerInstallDirectory.fromThisFolder,$finding.id)
        $scriptFile     =   (Get-ChildItem -Path $scriptFolder).BaseName
        $recId          = 0
        foreach($entry in (Invoke-PSCMD @{
            Session                 = @(Get-PSSession -Name $instance.HostName)
            PowerShellScriptFolder  = $scriptFolder
            PowerShellScriptFile    = $scriptFile
            ArgumentList            = @($instance)
            AsJob                   = $false
        })){
            $instance.CheckSQLServerInstallDirectory.Results += [pscustomobject]@{
                RecID   = $recId++
                HostName = $instance.HostName
                InstanceName = $instanceName
                FolderPath = $entry
            }
        }
    }
}

# Get: SQL Server Binary Hashes
foreach($instance in $newHostList){
    $instanceName = $instance.HostName
    $databaseName = $instance.GetSQLServerBinnFileHash.checkThisInstance.databaseName
    if($instance.isNamedInstance -eq 'true'){
        $instanceName = "{0}\{1}" -f $instance.HostName,$instance.InstanceName
    }

    Write-Host "[CHECK : GetSQLServerBinnFileHash] - HostName: $($instance.HostName) - InstanceName: $instanceName" -ForegroundColor Cyan

    foreach($finding in $instance.GetSQLServerBinnFileHash.givenTheseFindings){
        $scriptFolder   =   ("{0}{1}\" -f $instance.GetSQLServerBinnFileHash.fromThisFolder,$finding.id)
        $scriptFile     =   (Get-ChildItem -Path $scriptFolder).BaseName
        foreach($entry in (Invoke-PSCMD @{
            Session                 = @(Get-PSSession -Name $instance.HostName)
            PowerShellScriptFolder  = $scriptFolder
            PowerShellScriptFile    = $scriptFile
            ArgumentList            = @($instance)
            AsJob                   = $false
        })){
            $instance.GetSQLServerBinnFileHash.Results += [pscustomobject]@{
                RecID           = $entry.RecId
                HostName        = $entry.HostName
                InstanceName    = $entry.InstanceName
                DateTimeHashed  = $entry.DateTimeHashed
                FullName        = $entry.FullName
                Algo            = $entry.Algo
                Hash            =  $entry.Hash
            }
        }
    }
}
# Get: SQL Server Binary Hashes
foreach($instance in $newHostList){
    $instanceName = $instance.HostName
    if($instance.isNamedInstance -eq 'true'){
        $instanceName = "{0}\{1}" -f $instance.HostName,$instance.InstanceName
    }

    Write-Host "[CHECK : GetSQLInstallationAccounts] - HostName: $($instance.HostName) - InstanceName: $instanceName" -ForegroundColor Cyan

    foreach($finding in $instance.GetSQLInstallationAccounts.givenTheseFindings){
        $scriptFolder   =   ("{0}{1}\" -f $instance.GetSQLInstallationAccounts.fromThisFolder,$finding.id)
        $scriptFile     =   (Get-ChildItem -Path $scriptFolder).BaseName
        foreach($entry in (Invoke-PSCMD @{
            Session                 = @(Get-PSSession -Name $instance.HostName)
            PowerShellScriptFolder  = $scriptFolder
            PowerShellScriptFile    = $scriptFile
            ArgumentList            = @($instance)
            AsJob                   = $false
        })){
            $instance.GetSQLInstallationAccounts.Results += [pscustomobject]@{
                RecID           = $entry.RecId
                HostName        = $entry.HostName
                InstanceName    = $entry.InstanceName
                IsApproved      = $entry.IsApproved
                FullName        = $entry.FullName
                Login           = $entry.Login
            }
        }
    }
}

$newHostList.CheckConfig.Results                        | Format-Table -Autosize
$newHostList.CheckRegistryPermissions.Results           | Format-Table -Autosize
$newHostList.CheckStoredProcedures.Results              | Format-Table -Autosize
$newHostList.CheckInstalledFeatures.Results             | Format-Table -Autosize
$newHostList.CheckSQLServerBinaryPermissions.Results    | Format-Table -Autosize
$newHostList.CheckSQLLoginPermissions.Results           | Format-Table -Autosize
$newHostList.CheckSQLLoginDescriptions.Results          | Format-Table -Autosize
$newHostList.CheckSQLServerInstallDirectory.Results     | Format-Table -Autosize
$newHostList.GetSQLServerBinnFileHash.Results           | Format-Table -Autosize
$newHostList.GetSQLInstallationAccounts.Results         | Format-Table -Autosize
