$cmsName = 'TOG-SQL'
$i = 0

#Default values
$BlockedProcessThreshold = 5
$JobHistoryMaxRows = 500000 
$JobHistoryMaxRowsPerJob = 1000
$FillFactor = 85

function ASH-CheckSQLAgent {
    [cmdletbinding(SupportsShouldProcess=$True)]
    param (
        [Parameter(Mandatory=$true)][ref]$Server,
        [switch]$AutoFix
    )
    
    $svr = $Server.value 

    #make sure that SQL agent is available
    if ($svr.JobServer -eq $null) {
        return;
    }

    $Agent = $svr.JobServer

    #check for operator "DBA - Team"
    if ($Agent.operators.Contains("DBA - Team") -ne $true) {
        Write-Output "$($svr.Name) missing 'DBA - team' operator"

        if ($AutoFix) {
            if($PSCmdlet.ShouldProcess($($svr.Name),"Adding operator 'DBA - Team'")) {
                $op = New-Object ('Microsoft.SqlServer.Management.Smo.Agent.Operator') ($Agent, $oper)
                $op.EmailAddress = "tog-dba@ashn.com"
                $op.Name = 'DBA - Team'
                $op.enabled = $True
                $op.create()    
                Write-Output "`tOperator Created"
            }
        }
    }
    else {
        Write-Verbose "$($svr.Name) missing 'DBA - team' operator"
    }

    #check Job History Max Rows
    if ($Agent.MaximumHistoryRows -ne $JobHistoryMaxRows) {
        Write-Output "$($svr.Name) Job History Max Rows is: $($Agent.MaximumHistoryRows) should be $($JobHistoryMaxRows)"
        if ($AutoFix) {
            if($PSCmdlet.ShouldProcess($($svr.Name),"Setting Job History Max Rows")) {
                $Agent.MaximumHistoryRows = $JobHistoryMaxRows
                $Agent.Alter()
                Write-Output "`tJob History Max Rows set to $($JobHistoryMaxRows)"
            }
        }
    }
    else {
        Write-Verbose "$($svr.Name) Job History Max Rows is: $($Agent.MaximumHistoryRows)"
    }

    # Check Max rows per job
    if ($svr.JobServer.MaximumJobHistoryRows -ne $JobHistoryMaxRowsPerJob) {
        Write-Output "$($svr.Name) Job History Max Rows per Job is: $($svr.JobServer.MaximumJobHistoryRows) should be $($JobHistoryMaxRowsPerJob)"
        if ($AutoFix) {
            if($PSCmdlet.ShouldProcess($($svr.Name),"Setting Job History Max Rows per Job")) {
                $Agent.MaximumJobHistoryRows = $JobHistoryMaxRowsPerJob
                $Agent.Alter()
                Write-Output "`tJob History Max Rows per Job set to $($JobHistoryMaxRowsPerJob)"
            }
        }
    }
    else {
        Write-Verbose "$($svr.Name) Job History Max Rows per Job is: $($svr.JobServer.MaximumJobHistoryRows)"
    }
}

function ASH-CheckSQLMail {
    [cmdletbinding(SupportsShouldProcess=$True)]
    param (
        [Parameter(Mandatory=$true)][ref]$Server,
        [switch]$AutoFix
    )

    $svr = $Server.value
    
    # check for SQl mail Enabled
    if ($svr.Configuration.DatabaseMailEnabled.ConfigValue -ne $True) {
        Write-Output "$($svr.Name) Database Mail-Disabled"    
        if ($AutoFix) {                
            if($PSCmdlet.ShouldProcess($($svr.Name),"Enabling Database Mail")) {
                $svr.Configuration.DatabaseMailEnabled.ConfigValue = $True
                $svr.Configuration.alter()
                Write-Output "`tDatabase Mail: $($svr.Configuration.DatabaseMailEnabled.ConfigValue)"                    
            }
        }
    } #end SQL mail Enabled
    else { 
        Write-Verbose "$($svr.Name) Database Mail: $($svr.Configuration.DatabaseMailEnabled.ConfigValue)"
    }

    # Check that the SQL agent mail profile is configured
    if ($svr.JobServer -ne $null) {
        if ($svr.JobServer.AgentMailType -ne 'DatabaseMail') {
            Write-Output "$($svr.Name) Agent Mail Type isn't configured for DatabaseMail"
        }

        if ($svr.jobserver.DatabaseMailProfile.length -eq 0) {
            Write-Output "$($svr.Name) Agent Database Mail Profile isn't configured"
        }
    }

    # Check SQL Mail Configured correctly



}

Function ASH-CheckSQLAdmin {
    [cmdletbinding(SupportsShouldProcess=$True)]
    param (
        [Parameter(Mandatory=$True)][string]$domain,
        [Parameter(Mandatory=$true)][ref]$Server,
        [switch]$AutoFix,[Parameter(Mandatory=$true, ValueFromPipeline = $true)]
        [string[]]$LoginNames,
        [string[]]$RoleNames
    )
    begin {
        $svr = $Server.value
    }

    process {
    
        foreach ($LoginName in $LoginNames) {

            $user = Get-ADUser -Filter {sAMAccountName -eq $LoginName}
            $group = Get-ADGroup -Filter {Name -eq $LoginName}

            if (-not $user -and -not $group) {
                continue;
            }

            $LoginName = "$($domain)\$($LoginName)"


            #check for the Server Login
            if ($svr.Logins.Contains($LoginName) -ne $True) {
                Write-Output "$($svr.Name) missing login: $($LoginName)"
                if ($AutoFix) {                
                    if($PSCmdlet.ShouldProcess($($svr.Name),"Adding Login $($LoginName)")) {
                        $Login = New-Object ("Microsoft.SqlServer.Management.Smo.Login -ArgumentList") $srv, $LoginName
                        $Login.LoginType = ‘WindowsUser’
                        $Login.PasswordPolicyEnforced = $false
                        $Login.script()
                        Write-Output "`tAdded Login: $($LoginName)" 
                    }
                }
                else {
                    return;
                }
            }

            $Login = New-Object ("Microsoft.SqlServer.Management.Smo.Login -ArgumentList") $Server.value, $LoginName

            # Ensure login can log into the server
    

            # Make sure it's in the specified roles
            foreach($RoleName in $RoleNames) {
                if ($Login.IsMember($RoleName) -ne $True) {
                    Write-Output "$($svr.Name) $($LoginName) not in $($RoleName)"
                }
                else {
                    Write-Verbose "$($svr.Name) has $($LoginName) in $($RoleName)"
                }
            }
        }
    }
}

Function ASH-RemoveLogins {
    [cmdletbinding(SupportsShouldProcess=$True)]
    param (
        
        [Parameter(Mandatory=$true)][ref]$Server,
        [switch]$AutoFix,
        [Parameter(Mandatory=$true, ValueFromPipeline = $true)]
        [string[]]$LoginNames
        )
    begin {
        $svr = $Server.value
    }

    Process {
        foreach ($LoginName in $LoginNames) {
            #Check to see if the login exists
            if ($svr.Logins.Contains($LoginName) -eq $True) {
                Write-Output "$($svr.Name) Login needs removed: $($LoginName)"

                return;
            }  
            else {
                Write-Verbose "$($svr.Name) doesn't have Login: $($LoginName)"
            }  
        }
    }
}

function ASH-CheckDDLTrigger{
    [cmdletbinding(SupportsShouldProcess=$True)]
    param (
        
        [Parameter(Mandatory=$true)][ref]$Server,
        [switch]$AutoFix,
        [Parameter(Mandatory=$true, ValueFromPipeline = $true)]
        [string[]]$Triggers,
        [string]$File
        )
    begin {
        $svr = $Server.value
    }

    Process {
        foreach ($trigger in $Triggers){
            if (-not $svr.Triggers.Contains($Trigger)) {
                Write-Output "$($svr.Name) missing DDL trigger: $($Trigger)"
                if ($AutoFix) {
                    if(Test-Path($File)) {
                        if($PSCmdlet.ShouldProcess($($svr.Name),"Adding DDL Trigger: $($trigger)")) {
                            
                        }
                    }
                    else {Write-Output "File Missing $($File)"}
                }
                else{
                    Write-Verbose "$($svr.Name) has DDL Trigger: $($trigger)"
                }
            }
        }
    }
}

function ASH-CheckTrace {
    [cmdletbinding(SupportsShouldProcess=$True)]
    param (
        
        [Parameter(Mandatory=$true)][ref]$Server,
        [switch]$AutoFix,
        [Parameter(Mandatory=$true, ValueFromPipeline = $true)]
        [int]$Trace
        )
    begin {
        $svr = $Server.value
    }
    process {
        $TraceFlags = $svr.EnumActiveGlobalTraceFlags()        
        $check = $false
        
        #loop through the trace flags and add the servername in order to create an object with all the required rows to import into a table later
        ForEach($TraceFlag in $TraceFlags) {
            if ($TraceFlag.TraceFlag -eq $Trace) {
                $check = ($TraceFlag.TraceFlag -eq $Trace)
                break;
            }
        }

        if (-not $check) {
            Write-Output "$($svr.Name) is missing Trace: $($Trace)"
        }
        else {
            Write-Verbose "$($svr.Name) has startup trace: $($Trace)"
        }

    }
}

function get-localAdmin {
    param (
        $ComputerName
    )

    $admins = gmwi win32_group_user -computer $ComputerName
    $admins = $admins |? {$_.groupcomponent –like '*"Administrators"'}  
      
    $admins |
        % { $_.partcomponent –match “.+Domain\=(.+)\,Name\=(.+)$” > $nul  
            $matches[1].trim('"') + “\” + $matches[2].trim('"')  
        }  
}

function ASH-LockedPagesFileInit {
    [cmdletbinding(SupportsShouldProcess=$True)]
    param (
        
        [Parameter(Mandatory=$true)][ref]$Server,
        [switch]$AutoFix
        )
    begin {
        $svr = $Server.value
    }
    process {
        
        Write-Verbose "$($svr.name) Unable to check Loacked pages into ram & Instant File Initialization"
            
            #$adminlist = get-localAdmin $srv

            #$proc = Get-CimInstance Win32_Process -Filter "name = 'sqlservr.exe'" -ComputerName $svr

<#                        
        Invoke-Command  -ComputerName $svr.name -ArgumentList $srv.Version.major -ScriptBlock {
            param([int]$MajorVersion)

            Set-Location C:\
            
            $ADSIComputer = [ADSI]("WinNT://$Env:COMPUTERNAME,computer") 
            $group = $ADSIComputer.psbase.children.find('Administrators',  'Group') 

            $admins = @()
            $admins = $group.psbase.invoke("members") |
                Where-Object {$_.GetType().InvokeMember("Name",  'GetProperty',  $null,  $_, $null) -in "SQLAdmin", "Domain Admins" }` |
                ForEach {
                    $_.GetType().InvokeMember("Name",  'GetProperty',  $null,  $_, $null)
                } 
               

            #$proc = Get-CimInstance Win32_Process -Filter "name = 'sqlservr.exe'" -ComputerName
            
            $admins = get-localAdmin $srv.name
            
            $Opt = New-CimSessionOption -Protocol Dcom
            $CimSession = New-CimSession -ComputerName $svr -SessionOption $Opt
            $proc = Get-CimInstance Win32_Process -Filter "name = 'sqlservr.exe'" -CimSession $CimSession
            $CimMethod = Invoke-CimMethod -InputObject $proc -MethodName GetOwner 
            $objUser = New-Object System.Security.Principal.NTAccount($CimMethod.Domain, $CimMethod.User)
        
            #$objUser = New-Object System.Security.Principal.NTAccount("CORP", "SQLAdmin")
            $strSID = $objUser.Translate([System.Security.Principal.SecurityIdentifier])
            $NTName = $strSID.Value

            $ManageVolumePriv = 0
            $LockPagesPriv = 0

            secedit /export /areas USER_RIGHTS /cfg UserRights.inf /quiet
 
            $FileResults = Get-Content UserRights.inf
 
            Remove-Item UserRights.inf

            $administrators = 'S-1-5-32-544'
          
            foreach ($line in $FileResults) {
                #$line
                if($line -like "SeManageVolumePrivilege*" -and ($line -contains "$NTName" -or ($line -like "*$($administrators)*" -and $admins.Count -gt 0))) {
                    #$line
                    $ManageVolumePriv = 1
                }
  
                if($line -like "SeLockMemoryPrivilege*" -and ($line -like "*$NTName*" -or ($line -like "*$($administrators)*" -and $admins.Count -gt 0))) {
                    #$line
                    $LockPagesPriv = 1
                }
            }

            if ($ManageVolumePriv -eq 0) {                
                Write-Output "$($svr.Name) Instant File Initialization is disabled"
            }

            if ($MajorVersion -ge 11 -and $LockPagesPriv -eq 0) {
                Write-Output "$($svr.Name) Lock Pages In Memory"
            }       
            
        }
#>
    }
}

function ASH-CheckBestPractices {
    [cmdletbinding(SupportsShouldProcess=$True)]
    param (
        [switch]$AutoFix,
        [Switch]$NoProgress,
        [String[]] $ServerGroups,
        [String[]] $ServerList
    )

    $StartTime = get-date

    . "\\tog-sql\SOG\Apps\Microsoft\SQL Server\Powershell\Scripts\get-PowerPlan.ps1"
    . "\\tog-sql\SOG\Apps\Microsoft\SQL Server\Powershell\Scripts\set-PowerPlan.ps1"
    . "\\tog-sql\SOG\Apps\Microsoft\SQL Server\Powershell\Scripts\get-serverlist.ps1"

    # Connect to the SQL CMS Server
    $connectionString = "data source=$cmsName;initial catalog=master;integrated security=sspi;" 
    $sqlConnection = New-Object ("System.Data.SqlClient.SqlConnection") $connectionstring 
    $conn = New-Object ("Microsoft.SQLServer.Management.common.serverconnection") $sqlconnection 
    $cmsStore = New-Object ("Microsoft.SqlServer.Management.RegisteredServers.RegisteredServersStore") $conn 
    $cmsRootGroup = $cmsStore.ServerGroups["DatabaseEngineServerGroup"].ServerGroups

    # Get the servers from the CMS Groups
    foreach ($group in $ServerGroups) {        
        Get-ServerList -cmsName $cmsName -serverGroup $group -recurse | foreach -process { $ServerList += $_.servername}
    }

    # no serverlist or group passed in, so process the whole CMS
    if ($ServerList.Count -eq 0) {
        #$cmsRootGroup.RegisteredServers | Sort-Object -property servername -unique | foreach -process { $ServerList += $_.servername}     
        Get-ServerList -cmsName $cmsName -recurse | foreach -process { $ServerList += $_.servername}
    }

    if ($ServerList.Count -eq 0) {
        Write-Output "No servers to process"
        break;
    }

    # get a list of all of the unique registered servers on the CMS
    #$servers = $cmsRootGroup.RegisteredServers | Sort-Object -property servername -unique  #| gm

    $serverlist = $serverlist | Sort-Object -unique

    cls

    # Loop through the servers
    foreach($svr in $ServerList) {

        if([ipaddress]::TryParse($svr, [ref]$null)) {
            $svr = [System.Net.Dns]::GetHostByAddress($svr).hostname.split(".")[0]
        }        
        
        if($NoProgress -ne $True) { 
            Write-Progress -Activity "Processing $($svr)" -PercentComplete ($i/$ServerList.Count*100)
        }

        #Write-Output "$($svr.servnameer)"
        $i += 1

        #connect to the sql server
        $server  = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $svr 

        if ($server.Status -eq $null) {
            continue;
        }

        #SQL agent Checks
        ASH-CheckSQLAgent -Server ([ref]$Server) -AutoFix:([bool]$AutoFix) 

        #SQl Mail Checks
        ASH-CheckSQLMail -Server ([ref]$Server) -AutoFix:([bool]$AutoFix) 

        #Check Logins
        @("sql_agent", "sql_server", "SQL_Level_3", "Domain Admins") | 
            ASH-CheckSQLAdmin -Server ([ref]$Server) -AutoFix:([bool]$AutoFix) -RoleNames "sysadmin" -domain "CORP" 
        @("BUILTIN\Administrators") |
            ASH-RemoveLogins -Server ([ref]$Server) -AutoFix:([bool]$AutoFix) 

        # check for compressed backup (2008R2 or greater)
        if ($server.Version.Major -gt 10 -or ($server.Version.Major -eq 10 -and $server.Version.Minor -eq 50)) {
            if ($server.Configuration.DefaultBackupCompression.ConfigValue -ne $true) {
                Write-Output "$($server.Name) not configured for compressed backups"
                if ($AutoFix) {                
                    if($PSCmdlet.ShouldProcess($($server.Name),"Setting Compressed backup default")) {
                        $server.Configuration.DefaultBackupCompression.ConfigValue = $True
                        $server.Configuration.alter()
                        Write-Output "`tCompressed backups: $($server.Configuration.DefaultBackupCompression)"                    
                    }
                }
            }   
            else {
                Write-Verbose "$($server.Name) configured for compressed backups"
            }
        }

        # check for Blocked Process Threshold
        if ($server.configuration.BlockedProcessThreshold.ConfigValue -ne $BlockedProcessThreshold) {
            Write-Output "$($server.Name) Blocked Process Threshold is $($server.configuration.BlockedProcessThreshold.ConfigValue) should be $($BlockedProcessThreshold)"
            if ($AutoFix) {
                if($PSCmdlet.ShouldProcess($($server.Name),"Setting Blocked Process Threshold")) {
                    $server.configuration.BlockedProcessThreshold.ConfigValue = $BlockedProcessThreshold
                    $server.Configuration.alter()
                    Write-Output "`tBlocked Process Threshold: $($server.Configuration.BlockedProcessThreshold.ConfigValue)" 
                }
            }            
        }
        else {
            Write-Verbose "$($server.Name) Blocked Process Threshold is $($server.configuration.BlockedProcessThreshold.ConfigValue)"
        }

        # set the default fill factor
        if ($server.configuration.FillFactor.ConfigValue -ne $FillFactor) {
            Write-Output "$($server.Name) Default Fill Factor is $($server.configuration.FillFactor.ConfigValue) should be $($FillFactor)"
            if ($AutoFix) {
                if($PSCmdlet.ShouldProcess($($server.Name),"Setting Default Fill Factor")) {
                    $server.configuration.FillFactor.ConfigValue = $FillFactor
                    $server.Configuration.alter()
                    Write-Output "`tBlocked Process Threshold: $($server.Configuration.FillFactor.ConfigValue)" 
                }
            }
        }
        else {
            Write-Verbose "$($server.Name) Default Fill Factor is $($server.configuration.FillFactor.ConfigValue)"
        }


        # Default Trace
        if ($server.Configuration.DefaultTraceEnabled.ConfigValue -ne $True) {
            Write-Output "$($server.Name) Defautlt Trace is disabled"
            if ($AutoFix) {
                if($PSCmdlet.ShouldProcess($($server.Name),"Enabling Defautlt Trace")) {
                    $server.Configuration.DefaultTraceEnabled.ConfigValue = $True
                    $server.Configuration.Alter()
                    Write-Output "`tDefautlt Trace Enabled: $($server.Configuration.DefaultTraceEnabled.ConfigValue)"                    
                }
            }
        }
        else {
            Write-Verbose "$($server.Name) Defautlt Trace Enabled: $($server.Configuration.DefaultTraceEnabled.ConfigValue)"  
        }

        #MAXDOP
        $cpuCount = $server.AffinityInfo.Cpus.Count
        $maxdop = $server.Configuration.MaxDegreeOfParallelism.ConfigValue
        switch ($cpuCount) {
            1 {$stdMaxDOP = 1}
            2 {$stdMaxDOP = 1}
            4 {$stdMaxDOP = 2}
            8 {$stdMaxDOP = 4}
            16 {$stdMaxDOP = 8}
            default {$stdMaxDOP = 8}
        }
        IF($maxdop -ne $stdMaxDOP) {
            Write-Output "$($server.Name) MAXDOP is $($maxdop) should be $($stdMaxDOP) for $($cpuCount) CPUs"        
            if ($AutoFix) {
                if($PSCmdlet.ShouldProcess($($server.Name),"Setting MaxDOP to $($stdMaxDOP)")) {
                    $server.Configuration.MaxDegreeOfParallelism.ConfigValue = $stdMaxDOP
                    $server.Configuration.Alter()
                    Write-Output "`tMaxDOP set to: $($stdMaxDOP)"
                }
            }
        }
        else {
            Write-Verbose "$($server.Name) MAXDOP is $($maxdop) for $($cpuCount) CPUs"  
        }

        # check for Remote DAC
        if ($server.Configuration.RemoteDacConnectionsEnabled.ConfigValue -ne $True) {
            Write-Output "$($server.Name) Remote DAC is disabled"
            if ($AutoFix) {
                if($PSCmdlet.ShouldProcess($($server.Name),"Enabling Remote DAC")) {
                    $server.Configuration.RemoteDacConnectionsEnabled.ConfigValue = $True
                    $server.Configuration.Alter()
                    Write-Output "`Remote DAC Enabled: $($server.Configuration.RemoteDacConnectionsEnabled.ConfigValue)"                    
                }
            }
        }
        else {
            Write-Verbose "$($server.Name) Remote DAC Enabled: $($server.Configuration.RemoteDacConnectionsEnabled.ConfigValue)"
        }

        # check for xp_cmdshell
        if ($server.Configuration.XPCmdShellEnabled.ConfigValue -ne $True) {
            Write-Output "$($server.Name) XP_CMDShell is disabled"
            if ($AutoFix) {
                if($PSCmdlet.ShouldProcess($($server.Name),"Enabling XP_CMDShell")) {
                    $server.Configuration.XPCmdShellEnabled.ConfigValue = $True
                    $server.Configuration.Alter()
                    Write-Output "`tXP_CMDShell Enabled: $($server.Configuration.XPCmdShellEnabled.ConfigValue)"                    
                }
            }
        }
        else {
            Write-Verbose "$($server.Name) XP_CMDShell Enabled: $($server.Configuration.XPCmdShellEnabled.ConfigValue)"
        }

        # Check memory
        $ServerRamMB =[math]::round( (Get-WMIObject -class Win32_PhysicalMemory -ComputerName $server.name.split("\")[0] | Measure-Object -Property capacity -Sum).sum/1mb , 2)
        $SQLMinRam = [math]::Round($Server.Configuration.MinServerMemory.ConfigValue / 1kb, 2)
        $SQLMaxRam = [math]::Round($Server.Configuration.MaxServerMemory.ConfigValue / 1kb, 2)
    
        $newRam = $ServerRamMB * .85 
        if ($newRam -le 4096) {$newRam = 3072}
        elseif ($newRam -le 6144) { $newRam = 4096}    
            
        IF ($ServerRamMB -lt 4096) {
            "$($Server.Name) has less than 4GB of RAM, please upgrade the server. ($($ServerRamMB) MB)"        
        }
        elseif ($SQLMaxRam -eq 2097152) {
            Write-Output "$($server.Name) MAX Memory is set to the default: $($SQLMaxRam) server ram is: $($ServerRamMB)"
            if ($AutoFix) {                                
                if($PSCmdlet.ShouldProcess($($server.Name),"Setting Max memory to: $($SQLMaxRam)")) {
                    $Server.Configuration.MaxServerMemory.ConfigValue = $newram
                    $server.Configuration.Alter()
                    Write-Output "`Max Memory set to: $($newram)"  
                }
            }
        }
        elseif ($SQLMaxRam -gt $newRam) {
            Write-Output "$($server.Name) MAX Memory is set to high: $($SQLMaxRam) server ram is: $($ServerRamMB)"
            if ($AutoFix) {
                if($PSCmdlet.ShouldProcess($($server.Name),"Setting Max memory to: $($SQLMaxRam)")) {
                    $Server.Configuration.MaxServerMemory.ConfigValue = $newram
                    $server.Configuration.Alter()
                    Write-Output "`Max Memory set to: $($newram)"                    
                }
            }
        }
        else {
            Write-Verbose "$($server.Name) MAX Memory is set to: $($SQLMaxRam)GB server ram is: $($ServerRamMB/1KB)GB"
        }

        # Check for the trace flags
        ASH-CheckTrace -Server ([ref]$Server) -AutoFix:([bool]$AutoFix) -Trace:3226
        ASH-CheckTrace -Server ([ref]$Server) -AutoFix:([bool]$AutoFix) -Trace:1118

        # Check for triggers
        ASH-CheckDDLTrigger -Server ([ref]$Server) -AutoFix:([bool]$AutoFix) -Trigger:"DDL_Database_Attemped_DROP_Trigger" `
            -File "\\tog-sql\sog\Apps\Microsoft\SQL Server\Scripts\Post Install Scripts\DDL_Database_Attemped_DROP_Trigger.sql"
        ASH-CheckDDLTrigger -Server ([ref]$Server) -AutoFix:([bool]$AutoFix) -Trigger:"DDL_Database_DROPPED_Trigger" `
            -File "\\tog-sql\sog\Apps\Microsoft\SQL Server\Scripts\Post Install Scripts\DDL_Database_DROPPED_Trigger.sql"
        ASH-CheckDDLTrigger -Server ([ref]$Server) -AutoFix:([bool]$AutoFix) -Trigger:"DDL_Database_ALTERED_Trigger" `
            -File "\\tog-sql\sog\Apps\Microsoft\SQL Server\Scripts\Post Install Scripts\DDL_Database_ALTERED_Trigger.sql"

        # Check for Locked Pages in Memory & Instant File initialization
        ASH-LockedPagesFileInit -Server ([ref]$server) -AutoFix:([bool]$AutoFix) 

        # Check Power Plan        
        $plan = Test-DbaPowerPlan -ComputerName $server.name -Detailed
        
        #$plan = Get-PowerPlan -ServerNames $server.Name
        if ($plan.ActivePowerPlan -ne "High performance" -and $plan.ActivePowerPlan -ne $null) {
            Write-Output "$($server.Name) Powerplan set to: $($plan.ActivePowerPlan)"    
            if ($AutoFix) {
                if($PSCmdlet.ShouldProcess($($server.Name),"Setting PowerPlan to: High Performance")) {
                    Set-DbaPowerPlan  -ComputerName $server.name 


                    #Set-PowerPlan -PreferredPlan 'High performance' -ServerNames $server.Name
                    #$plan = Get-PowerPlan -ServerNames $server.Name
                    Write-Output "`tPower Plan: $($plan)"
                }
            }
        } # End Power Plan
        else {
            Write-Verbose "$($server.Name) Powerplan set to: $($plan.PowerPlan)"
        }

        #check PowerScheme win 2003 only


    }

    $EndTime = get-date
    $RunTime = New-TimeSpan -Start $StartTime -End $EndTime
    Write-Output "Process started at: $($StartTime)"
    Write-Output "Process ended   at: $($EndTime)"
    Write-Output "Run Duration: $("{0:hh}:{0:mm}:{0:ss}" -f $RunTime)"
}


#ASH-CheckBestPractices -ServerList @("SD-ERWINSQL", "SD-SQLX3\SAGEX3") -NoProgress #-AutoFix #-WhatIf
<#
ASH-CheckBestPractices | 
    tee "\\tog-sql\SOG\Apps\Microsoft\SQL Server\ASH Best Practice Log\ASH-BestPractices $(get-date -Format "yyyy-MM-dd HHmmss").txt" 
#>
#ASH-CheckBestPractices -NoProgress
#$error[0]|format-list -force
#ASH-CheckBestPractices -ServerList "SD-devsql" -WhatIf

#ASH-CheckBestPractices -ServerGroups "telecom"

$Servers = @()
$Servers += "SD-S-SFGWSQL"
$Servers += "SD-S-SFCCSQL"
$Servers += "SD-D-SFGWSQL"
$Servers += "SD-D-SFCCSQL"
$Servers += "SD-P-SFGWSQL"
$Servers += "SD-P-SFCCSQL"

ASH-CheckBestPractices -ServerList $Servers -WhatIf #-Verbose

#$servers | Test-DbaDiskAlignment -Detailed