# reload profile if you havent alreay
.$PROFILE

# path to script folder, name of script
$CURRENT_PSSCRIPTS  = "$env:HOMEPATH\Documents\LocalRepo\AdminTools\PSScripts"
$SCRIPT             = "Get-SQLInstances"


# get your credentials
if($null -eq $Creds){$Creds = Get-Credential}

$SESSIONS = Get-PSSession 

$HOST_LIST = @(
""
)

# create a session for each host
foreach($hostName in $HOST_LIST){
    try{
        Get-PSSession -Name $hostName -ErrorAction "Stop" | Out-Null
    }catch{
        $sessionParams = @{
            ComputerName    = $hostName
            Name            = $hostName
            Credential      = $Creds
            ErrorAction     = "Stop"
        }
        New-PSSession @sessionParams
    }
}


# run command against host list
$results = @()
foreach($session in $SESSIONS){
    $results += Invoke-PSCMD @{
        Session                 = @($session)
        PowerShellScriptFolder  = $CURRENT_PSSCRIPTS
        PowerShellScriptFile    = $SCRIPT
        ArgumentList            = @("")
        AsJob                   = $false
    }
}
return $results.values
