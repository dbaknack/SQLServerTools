$ErrorActionPreference  = "Stop"
$rootInstanceDirectory  = "C:\Program Files\"
$paramsFile             = "BackupPaths.csv"
$instanceJobsDirectory  = "\Microsoft SQL Server\MSSQL*.MSSQLSERVER\MSSQL\JOBS\"

$myParamsFile = Resolve-Path -Path "$($rootInstanceDirectory)$($instanceJobsDirectory)$($paramsFile)"

$paramsFilePathValid = [bool]
if(Test-Path -Path $myParamsFile.Path){
    $paramsFilePathValid = $true
}else{
    $paramsFilePathValid = $false
}

if(-not($paramsFilePathValid)){
    Write-Error -Message "$myParamsFile is invalid" -Category ObjectNotFound
}

$readContent = [bool]
try {
    $readContent = $true
    $myContent = Get-Content -Path $myParamsFile -ErrorAction Stop
}catch{
    $readContent = $false
}

if(-not($readContent)){
    Write-Error -Message "Unable to read content from $myParamsFile"
}

$backupParamsList = $myContent | Select-Object -Skip 2 | ForEach-Object {
    $_ -replace "\[([^;]*\])",""
} | ConvertFrom-Csv

foreach($row in $backupParamsList){
    $backupParams = @{
        RootDrive       = [string]$row.RootDrive
        BackupFolder    = [string]$row.BackupFolder
        InstanceName    = [string]$row.InstanceName
        DatabaseName    = [string]$row.DatabaseName
        TLogPath        = [string]$row.TLogPath
        RecoveryModel   = [int]$row.RecoveryModel
        BackupFullPath  = [string]
    }

    # check that the root directory is valid
    $rootDrive = $backupParams.RootDrive
    if(Test-Path -path $rootDrive){
        $rootExists = $true
    }else{
        $rootExists = $false
    }

    if(-not($rootExists)){
        Write-Error -Message "$($rootDrive) is invalid" -Category InvalidResult
    }
   
    # check backup folder exists
    $backupFolder = $rootDrive+$backupParams.BackupFolder
    if(Test-Path -path $backupFolder){
        $backupFolderExists = $true
    }else{
        $backupFolderExists = $false
    }

    if(-not($backupFolderExists)){
        New-Item -Path $backupFolder -ItemType Directory | Out-Null
    }

    # check backup instance folder exists
    $InstanceFolder = $backupFolder+$backupParams.InstanceName
    if(Test-Path -path $backupFolder){
        $instanceFolderExists = $true
    }else{
        $instanceFolderExists = $false
    }

    if(-not($instanceFolderExists)){
        New-Item -Path $InstanceFolder -ItemType Directory | Out-Null
    }

    #check database folder exists
    $databaseFolder = $InstanceFolder+$backupParams.DatabaseName

    if(Test-Path -path $databaseFolder){
        $datbaseFolderExists = $true
    }else{
        $datbaseFolderExists = $false
    }

    if(-not($datbaseFolderExists)){
        New-Item -Path $databaseFolder -ItemType Directory | Out-Null
    }

    # check recovery model being used
    $backupParams.BackupFullPath =  $databaseFolder
    $backupFullPath = $backupParams.BackupFullPath
    $myRecoveryModle = $backupParams.RecoveryModel
    if($myRecoveryModle -eq 1){
        $tlogFolder = $backupParams.TLogPath
        $tlogsFolderPath = "$($backupFullPath)$($tlogFolder)"
        $tlogsFolderExists = test-path -path $tlogsFolderPath

        if(-not($tlogsFolderExists )){
            New-Item -Path $tlogsFolderPath -ItemType Directory | Out-Null
        }
    }
}