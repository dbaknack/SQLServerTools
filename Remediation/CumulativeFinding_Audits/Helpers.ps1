$STIGVIEWERPATH = "$env:HOMEPATH\Documents"
$ENCLAVE = "DEVLAB"
function ll { Get-ChildItem -Path $pwd -File }
function lr { Set-Location $HOME\Documents}
function rr { Set-Location "R:\"}
function gcom {
    git add .
    git commit -m "$args"
}
function lazyg {
    git add .
    git commit -m "$args"
    git push
}
function Get-PubIP {
    (Invoke-WebRequest http://ifconfig.me/ip ).Content
}
function uptime {
    #Windows Powershell only
	If ($PSVersionTable.PSVersion.Major -eq 5 ) {
		Get-WmiObject win32_operatingsystem |
        Select-Object @{EXPRESSION={ $_.ConverttoDateTime($_.lastbootuptime)}} | Format-Table -HideTableHeaders
	} Else {
        net statistics workstation | Select-String "since" | foreach-object {$_.ToString().Replace('Statistics since ', '')}
    }
}

function reload-profile {
    & $profile
}
function find-file($name) {
    Get-ChildItem -recurse -filter "*${name}*" -ErrorAction SilentlyContinue | ForEach-Object {
        $place_path = $_.directory
        Write-Output "${place_path}\${_}"
    }
}
function unzip ($file) {
    Write-Output("Extracting", $file, "to", $pwd)
    $fullFile = Get-ChildItem -Path $pwd -Filter .\cove.zip | ForEach-Object { $_.FullName }
    Expand-Archive -Path $fullFile -DestinationPath $pwd
}
function ix ($file) {
    curl.exe -F "f:1=@$file" ix.io
}
function grep($regex, $dir) {
    if ( $dir ) {
        Get-ChildItem $dir | select-string $regex
        return
    }
    $input | select-string $regex
}
function touch($file) {
    "" | Out-File $file -Encoding ASCII
}
function df {
    get-volume
}
function sed($file, $find, $replace) {
    (Get-Content $file).replace("$find", $replace) | Set-Content $file
}
function which($name) {
    Get-Command $name | Select-Object -ExpandProperty Definition
}
function export($name, $value) {
    set-item -force -path "env:$name" -value $value;
}
function pkill($name) {
    Get-Process $name -ErrorAction SilentlyContinue | Stop-Process
}
function pgrep($name) {
    Get-Process $name
}

Function Invoke-UDFSQLCommand{
    param(
        [hashtable]$Query_Params
    )

    $processname = 'Invoke-UDFSQLCommand'
    $myQuery = "{0}" -f $Query_Params.Query
    $sqlconnectionstring = "
        server                          = $($Query_Params.InstanceName);
        database                        = $($Query_Params.DatabaseName);
        trusted_connection              = true;
        application name                = $processname;"
    # sql connection, setup call
    $sqlconnection                  = new-object system.data.sqlclient.sqlconnection
    $sqlconnection.connectionstring = $sqlconnectionstring
    $sqlconnection.open()
    $sqlcommand                     = new-object system.data.sqlclient.sqlcommand
    $sqlcommand.connection          = $sqlconnection
    $sqlcommand.commandtext         = $myQuery
    # sql connection, handle returned results
    $sqladapter                     = new-object system.data.sqlclient.sqldataadapter
    $sqladapter.selectcommand       = $sqlcommand
    $dataset                        = new-object system.data.dataset
    $sqladapter.fill($dataset) | out-null
    $resultsreturned                = $null
    $resultsreturned               += $dataset.tables
    $sqlconnection.close()      # the session opens, but it will not close as expected
    $sqlconnection.dispose()    # TO-DO: make sure the connection does close
    $resultsreturned
}
Function Invoke-PSSQL{
    param([hashtable]$Params)

    try{
        $SQLScript  = (Get-Content -Path (Get-ChildItem -path $Params.SQLScriptFolder -Filter "$($Params.SQLScriptFile).sql").FullName) -join "`n"
        $Params.ConnectionParams.Add("Query",$SQLScript)
    }catch{
        $Error[0] ; break
    }
    
    
    $InvokeParams = @{
        Session         = $Params.Session
        ArgumentList    = @{
            Func        = ${Function:Invoke-UDFSQLCommand}
            FuncParams  = $Params.ConnectionParams
        }
        ScriptBlock     = {
            param($ArgumentList)
            $ScriptBlock    = [scriptblock]::Create($ArgumentList.Func)
            $ArgumentList   = $ArgumentList.FuncParams
            Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList
        }
    }
    Invoke-Command @InvokeParams | select-object -Property * -ExcludeProperty "RunSpaceID"
}
Function Invoke-PSCMD{
    param([hashtable]$Params)
    begin{
        try{
            $PwshScript = (Get-Content -path (Get-ChildItem -path $Params.PowerShellScriptFolder -Filter "$($Params.PowerShellScriptFile).ps1").FullName) -join "`n"
        }catch{
            $Error[0]
        }
    }
    process{
        $results = $null
        foreach($Session in $Params.Session){
            $InvokeParams   = @{
                Session         = $Session
                ArgumentList    = @{
                    Func        = $PwshScript
                    FuncParams  = $Params.ArgumentList
                }
                ScriptBlock     = {
                    param($ArgumentList)
                    $ScriptBlock    = [scriptblock]::Create($ArgumentList.Func)
                    $ArgumentList   = $ArgumentList.FuncParams
                    Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList
                }
            }

            $results = switch($Params.AsJob){
                $true   {
                    (Invoke-Command @InvokeParams -AsJob | Out-Null)
                }
                $false  {
                    (Invoke-Command @InvokeParams)
                    }
            }
        }
    }
    end{
        return $results
    }
}
