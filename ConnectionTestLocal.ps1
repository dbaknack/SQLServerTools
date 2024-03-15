Invoke-PSCMD @{
    LocalHost       = $true
    ScriptBlock     = {get-host}
    ArgumentList    = @("hello")
    AsJob           = $false
}

$SQLScript  = (Get-Content -Path ".\SQLServerTools\Remediation\V-214039\GetPolyBaseConfiguration.sql") -join "`n"
$queryResults = Invoke-UDFSQLCommand @{
    InstanceName = '.'
    DatabaseName = 'Master'
    Query = $SQLScript
}
$SQLScript  = (Get-Content -Path ".\SQLServerTools\Remediation\V-214038\GetHadoopConfiguration.sql") -join "`n"
$queryResults = Invoke-UDFSQLCommand @{
    InstanceName = '.'
    DatabaseName = 'Master'
    Query = $SQLScript
}

$queryResults | ft -a
  
