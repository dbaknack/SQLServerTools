param([hashtable]$fromSender)

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


    if(-not($fromSender.isNamedInstance -eq "True")){
        $registry_instance_ref = "MSSQLSERVER"
    }else{
        $registry_instance_ref = $fromSender.InstanceName
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


$Results = @()
foreach($pathType in  $registryPaths.keys){
    if($pathType -eq 'SETUP'){
        foreach($feature in $registryPaths.$pathType.Properties.FeatureList){
            $Results += [pscustomobject]@{
                Enclave      = $fromSender.Enclave
                DomainName   = $env:USERDNSDOMAIN
                HostName     = $fromSender.HostName
                InstanceName = $fromSender.InstanceName
                Feature  = $feature.Feature
                State = $feature.FeatureStateValue
                Description = $feature.StateDescription
                IsApproved = $true
            }
        }
    }
}
return $Results
