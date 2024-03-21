param([hashtable]$InstanceAuditProperties)
$ErrorActionPreference = 'Stop'
$ScriptParams  = @{
    Name     = 'Create-AuditPaths'
    HostName = $env:COMPUTERNAME
}

<# Example:
    $InstanceAuditProperties = @{
        SCSM = @{RootDrive  = 'P:\';FolderName = 'Audit'}
        SCOM = @{RootDrive  = 'P:\';FolderName = 'Audit'}
    }
#>



foreach($instance in $InstanceAuditProperties.keys){
    $instanceProperties = $InstanceAuditProperties.$instance
    $msg = "[$($ScriptParams.HostName)]::[{0}]:: {1}" -f $ScriptParams.Name,"$($instance) - Checking Requirements:"
    Write-Host  $msg -ForegroundColor cyan

    # check: root drive exists
    $rootDrive = $instanceProperties.RootDrive
    if(-not(test-path -path $rootDrive)){
        $msgError = "[$($ScriptParams.HostName)]::[{0}]:: {1}" -f $ScriptParams.Name, "'$($rootDrive)' does not exists"
        Write-Host -Message $msgError -ForegroundColor Red; Throw
    }else{
         $msg = "[$($ScriptParams.HostName)]::[{0}]:: {1}" -f $ScriptParams.Name, "Drive '$($rootDrive)' does exists"
         Write-Host  $msg -ForegroundColor cyan
    }

    # check: audit folder exists
    $auditFolder = "{0}{1}" -f $instanceProperties.RootDrive,$instanceProperties.FolderName
    if(-not(test-path -path $auditFolder)){
        try{
            $itemCreated = $true
            $msg = "[$($ScriptParams.HostName)]::[{0}]:: {1}" -f $ScriptParams.Name, "'$($auditFolder)' does not exits"
            New-Item -Path $auditFolder -ItemType 'Directory' -ErrorAction Stop | Out-Null
        }catch{
            $itemCreated = $false
        }

        if(-not($itemCreated)){$Error[0]}
        $msg = "[$($ScriptParams.HostName)]::[{0}]:: {1}" -f $ScriptParams.Name, "'$($auditFolder)' created successfully"
        Write-Host $msg -ForegroundColor Cyan
    }else{
         $msg = "[$($ScriptParams.HostName)]::[{0}]:: {1}" -f $ScriptParams.Name, "The '$($auditFolder)' folder, already exists"
         Write-Host  $msg -ForegroundColor cyan
    }

    # check: instance specific audit folder exists
    $instanceAuditFolder = "{0}{1}\{2}" -f $instanceProperties.RootDrive,$instanceProperties.FolderName,$instance
    if(-not(test-path -path $instanceAuditFolder)){
        try{
            $itemCreated = $true
            $msg = "[$($ScriptParams.HostName)]::[{0}]:: {1}" -f $ScriptParams.Name, "'$($instanceAuditFolder)' does not exits"
            Write-Host $msg -ForegroundColor Cyan
            New-Item -Path $instanceAuditFolder -ItemType 'Directory' -ErrorAction Stop | Out-Null
        }catch{
            $itemCreated = $false
           
        }

        if(-not($itemCreated)){$Error[0]}
        $msg = "[$($ScriptParams.HostName)]::[{0}]:: {1}" -f $ScriptParams.Name, "'$($instanceAuditFolder)' created successfully"
        Write-Host $msg -ForegroundColor Cyan
    }else{
         $msg = "[$($ScriptParams.HostName)]::[{0}]:: {1}" -f $ScriptParams.Name, "The '$($auditFolder)' folder, already exists"
         Write-Host  $msg -ForegroundColor cyan
    }
    write-host ""
}
