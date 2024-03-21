# reload profile if you havent alreay
.$PROFILE

# path to script folder, name of script
$CURRENT_PSSCRIPTS  = "$env:HOMEPATH\Documents\LocalRepo\AdminTools\PSScripts"
$SCRIPT             = "Get-StorageStats"
$GENERATEASSESMENT  = $true # set to false if you dont know if you want this


# get your credentials
if($null -eq $Creds){$Creds = Get-Credential}

$SESSIONS = Get-PSSession 

$HOST_LIST = @(
	"Hosts"
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

# create a command to run against each host
$CMD_ARGS_TABLE = @{}
foreach($hostname in $HOST_LIST){
    $CMD_ARGS_TABLE.Add($hostName,@{
        Filter  = "Include"
        Label   = @("Page*")
        ENCLAVE = $ENCLAVE
    })
}

# run command against host list
$storageResults = @()
foreach($session in $SESSIONS){
    $storageResults += Invoke-PSCMD @{
        Session                 = @($session)
        PowerShellScriptFolder  = $CURRENT_PSSCRIPTS
        PowerShellScriptFile    = $SCRIPT
        ArgumentList            = @($CMD_ARGS_TABLE.($session.name))
        AsJob                   = $false
    }
}

$cntr = 1
$volReport = @()
foreach($entry in $storageResults){
    $recID = @{name =  "RecID2"; expression = {$cntr}} 
    $volReport += $entry | Select-Object -Property $recID,*
    $cntr = $cntr + 1
}



$USER_SWITCHES =@{
    Assesment = @{
        description = @(
            "when enabled, given the parameters provided, the following assesment will be generated"
            "when disabled, no assesment is generated."
            )
        enabled = $GENERATEASSESMENT
    }
}



if($USER_SWITCHES.Assesment.enabled){
    # run GetSQLIntances.ps1 in the current scope
    $instances = @()
    foreach($i in $results.values){
        $instances += $i
    }
    $myData = $volReport | Select-Object -Property @(
        "RecID2",
        "Enclave",
        "Domain",
        "HostName",
        "Name"
        "Label",
        "FreeSpacePercent",
        "CapacityGb",
        "UsedSpaceGb"
        "FreeSpaceGb"
    ) -ExcludeProperty @("RunspaceID","PSComputerName") 
    $assesmentData = @()

    $Remarks = @("NIPER - Assesment: Remediate Audit Related Findings"
    ""
    "To remediate the Audit related findings, an audit file will need to be created for each instance."
    "The Audit file(s) will be the catch-all for some events that DSCA outlines are required for analysis and monitoring."
    ""
    "The Audit file(s) will be configured to not grow beyond 10Gb in size, past that the oldest entries will start to drop off."
    "While testing, the Audit file(s) took 16 hours to fill up. Can't say for sure how quickly they will reach their limit when,"
    "actually capturing event, will just depent on the instance. SPLUNK will be used to capture and retain those entries."
    "Since it took about 16 hours to fill up, to satisfy the finding, SPLUNK should pull those records twice a day. Won't"
    "miss anything that way. Not to sure how SPLUNK works, but that would be the requirement for the AUDIT collection and retention"
    "requirement."
    ""
    "The finding does state that the SQL Instance should default to and off state when the Audit file(s) has no room to grow."
    ""
    "This does seem rather a drastic requirement to set, so the Audit file(s) will be configured to not default to off."
    ""
    "During testing, i did validate that it is the case that they will grow to the set size, and not beyond"
    "Also validated that usage of the TempDB log file won't grow sustantially more, due to the extra transactions taking place."
    "Will need to keep an eye on it since the workload tested was not really 1-to-1 with what we might see in reality."
    "Did see that the ERRORLOG file grew pretty fast, but I was testing the events the Audit will end up capturing, creating ErrorLog"
    "entries ever second for 16 hours. Dont expect that to be an issue when implementing the Audit file(s)."
    ""
    "If there is an issue with transaction log growth due to the Audit, the drive where it sits will need to be sized to accomodate"
    "the new requirements. Can't say for sure what that will be, but during testing i did not see any substatial growth."
    ""
    "Did see P:\ drive on a host had some old Audit file(s), was planning to use that for the Audit files. That being said"
    "Below is a report on NIPER of what those drive currently have as allocated space, used space, and available space."
    ""

    "")
    $stats = @()
    foreach($myEntry in $myData){

        $instProps = $instances | Select-Object -Property * | Where-Object {$_.host_name -eq $myEntry.HostName}
        $AuditPaths = @()
        foreach($instance in $instProps){
            if($instance.instance_type -eq "named"){
                $InstanceName = ($instance.instance_name -split ('\\'))[-1]
            }else{
                $InstanceName = $instance.instance_name 
            }
            $totalInstances = $instance.id
            $AuditPaths     += "{0}{1}\{2}"-f $myEntry.Name,"AUDITS",$InstanceName
        }
        $assesmentData += [pscustomobject]@{
            HostName = $myEntry.HostName
            AuditPaths = $AuditPaths
            TotalInstances = $totalInstances
        }

        foreach($entry in $assesmentData){
            $TotalSpaceUsedByAudits = $myEntry.UsedSpaceGb + (10*($entry.TotalInstances))
        }
        $ProjectedRequiredCapacity = $myEntry.CapacityGb * 0.75

        if(($TotalSpaceUsedByAudits -gt $myEntry.CapacityGb) -or ($TotalSpaceUsedByAudits -gt $ProjectedRequiredCapacity)){
            $addition = 100
            $MoreStorageRequired = $true
        }else{
            $addition = 0
            $MoreStorageRequired = $false
        }
        
        if(-not($MoreStorageRequired)){
            $Additional = $ProjectedRequiredCapacity - $myEntry.CapacityGb
        }

        
        $stats += "{0}    {1}     {2}     {3}         {4}       {5}" -f $myEntry.HostName,$myEntry.Name, $myEntry.CapacityGb, $myEntry.UsedSpaceGb, $TotalSpaceUsedByAudits, $addition
    }

    $Remarks += "SPLUNK might only need the UNC path to each AUDIT folder if it can recurse into it. Paths are listed below:"
    foreach($h in $assesmentData){
        $Remarks += "   Total Instances on this host '{0}'. UNC Path {1}{2}{3}" -f $h.TotalInstances,"\\",$h.HostName,"P:\AUDITS"
    }
    $Remarks += ""
    $Remarks += "If the full paths are required, there are listed below:"
    $Remarks += ""
    foreach($h in $assesmentData){
        foreach($path in $h.AuditPaths){
            $Remarks += "{0}{1}\{2}" -f "\\",$h.HostName,$path
        }
    }
    $Remarks +=@(
    " "
    "Each drive will need to accomodate without filling the drive itself and also be within 75% of the capacity of the drive."
    "Below i added that info:"
    " "
    "HostName           Drive   CapacityGb  UsedSpace   ProjectedUsedSpaceGB  AdditionalSpaceRequiredGb")
    $Remarks +=  $stats

    $Remarks += @(
        "Below are the things that will tracked:"
        ""
    )
    $Remarks +=@(
"APPLICATION_ROLE_CHANGE_PASSWORD_GROUP     Audit for changes to application role passwords."
"AUDIT_CHANGE_GROUP	                        Audit for changes to audit configurations."
"BACKUP_RESTORE_GROUP	                    Audit for backup and restore operations."
"DATABASE_CHANGE_GROUP	                    Audit for changes to databases."
"DATABASE_OBJECT_CHANGE_GROUP	            Audit for changes to database objects."
"DATABASE_OBJECT_OWNERSHIP_CHANGE_GROUP	    Audit for changes to database object ownership."
"DATABASE_OBJECT_PERMISSION_CHANGE_GROUP    Audit for changes to database object permissions."
"DATABASE_OPERATION_GROUP	                Audit for database operations."
"DATABASE_OWNERSHIP_CHANGE_GROUP	        Audit for changes to database ownership."
"DATABASE_PERMISSION_CHANGE_GROUP	        Audit for changes to database permissions."
"DATABASE_PRINCIPAL_CHANGE_GROUP	        Audit for changes to database principals."
"DATABASE_PRINCIPAL_IMPERSONATION_GROUP	    Audit for impersonation of database principals."
"DATABASE_ROLE_MEMBER_CHANGE_GROUP	        Audit for changes to database role members."
"DBCC_GROUP	                                Audit for Database Console Commands (DBCC) operations."
"LOGIN_CHANGE_PASSWORD_GROUP	            Audit for changes to login passwords."
"LOGOUT_GROUP	                            Audit for logouts."
"SCHEMA_OBJECT_CHANGE_GROUP	                Audit for changes to schema objects."
"SCHEMA_OBJECT_OWNERSHIP_CHANGE_GROUP	    Audit for changes to schema object ownership."
"SCHEMA_OBJECT_PERMISSION_CHANGE_GROUP	    Audit for changes to schema object permissions."
"SERVER_OBJECT_CHANGE_GROUP	                Audit for changes to server objects."
"SERVER_OBJECT_OWNERSHIP_CHANGE_GROUP	    Audit for changes to server object ownership."
"SERVER_OBJECT_PERMISSION_CHANGE_GROUP	    Audit for changes to server object permissions."
"SERVER_OPERATION_GROUP	                    Audit for server operations."
"SERVER_PERMISSION_CHANGE_GROUP	            Audit for changes to server permissions."
"SERVER_PRINCIPAL_CHANGE_GROUP	            Audit for changes to server principals."
"SERVER_PRINCIPAL_IMPERSONATION_GROUP	    Audit for impersonation of server principals."
"SERVER_ROLE_MEMBER_CHANGE_GROUP	        Audit for changes to server role members."
"SERVER_STATE_CHANGE_GROUP	                Audit for changes to server state."
"TRACE_CHANGE_GROUP	                        Audit for changes to traces."
"USER_CHANGE_PASSWORD_GROUP	                Audit for changes to user passwords."
"SUCCESSFUL_LOGIN_GROUP	                    Audit for successful logins."
"SCHEMA_OBJECT_ACCESS_GROUP	                Audit for access to schema objects."
"FAILED_LOGIN_GROUP	                        Audit for failed login attempts."
"DATABASE_OBJECT_ACCESS_GROUP	            Audit for access to database objects."
)

$Remarks | clip.exe

}else{
    $myData = $volReport | Select-Object -Property * 
    return $myData
}


