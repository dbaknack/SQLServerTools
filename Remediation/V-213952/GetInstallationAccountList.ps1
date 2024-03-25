param([hashtable]$fromSender)

Set-Location -path "C:\Program Files\Microsoft SQL Server\130\Setup Bootstrap\Log"
$accountsList = @()
foreach($itemMatch in (Get-ChildItem -Recurse | Select-String -Pattern "LogonUser = " )){
    $accountsList += [pscustomobject]@{
    LogonAs = ((($itemMatch -split (': '))[-1]) -split ' = ')[-1]
    }
}

$finalAccountsList = @()
$recID = 1
foreach($entry in (($accountsList | Group-Object -Property LogonAS -AsHashTable).keys)){
    $finalAccountsList += [pscustomobject]@{
        RecID           = $recID++
        HostName        = $fromSender.HostName
        InstanceName    = $fromSender.InstanceName
        IsApproved      = $true
        Login           = $entry
    }
}
return $finalAccountsList 
