<#
$servers = @()
$servers += "tog-sql"

 $srv = New-Object Microsoft.SqlServer.Management.Smo.Server $Server

function Test-SQLDefaults {
#>
    [CmdletBinding()]
    param(
        # Server Name or ServerName\InstanceName or an array of server names and/or servername\instancenames
        [Parameter(Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, 
        Position = 0)]
        [array]$Servers,
        # Expected SQL Admin Account or an array of accounts
        [Parameter(Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, 
            Position = 0)]
        [array]$SQLAdmins ,
        # Default Data Directory - Needs to match exactly including trailing slash if applicable
        [Parameter(Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, 
            Position = 0)]
        [string]$DataDirectory ,
        # Default Log Directory - Needs to match exactly including trailing slash if applicable
        [Parameter(Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, 
            Position = 0)]
        [string]$LogDirectory,

        # The frequency of the Ola Hallengrens System backups - Weekly, Daily
        [Parameter(Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, 
        Position = 0)]
        [string]$OlaSysFullFrequency ,
        # The start time of the Ola Hallengrens System backups - '21:00:00'
        [Parameter(Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, 
        Position = 0)]
        [string]$OlaSysFullStartTime ,
        # The retention time for System backups
        [Parameter(Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, 
        Position = 0)]
        [int]$OlaSysFullRetention ,

        # The frequency of the Ola Hallengrens User Full backups - Weekly, Daily
        [Parameter(Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, 
        Position = 0)]
        [string]$OlaUserFullSchedule ,
        # The frequency of the Ola Hallengrens User Full backups 
        # See https://msdn.microsoft.com/en-us/library/microsoft.sqlserver.management.smo.agent.jobschedule.frequencyinterval.aspx
        # for full options
        # 1 for Sunday 127 for every day
        [Parameter(Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, 
        Position = 0)]
        [string]$OlaUserFullFrequency ,
        # The start time of the Ola Hallengrens User Full backups - '21:00:00'
        [Parameter(Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, 
        Position = 0)]
        [string]$OlaUserFullStartTime ,
        # The retention time for User Full backups
        [Parameter(Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, 
        Position = 0)]
        [int]$OlaUserFullRetention,

        # The frequency of the Ola Hallengrens User Differential backups - Weekly, Daily
        [Parameter(Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, 
        Position = 0)]
        [string]$OlaUserDiffSchedule ,
        # The frequency of the Ola Hallengrens User Differential backups 
        # See https://msdn.microsoft.com/en-us/library/microsoft.sqlserver.management.smo.agent.jobschedule.frequencyinterval.aspx
        # for full options
        # 1 for Sunday 127 for every day
        [Parameter(Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, 
        Position = 0)]
        [string]$OlaUserDiffFrequency , ## 126 for every day except Sunday
        # The start time of the Ola Hallengrens User Differential backups - '21:00:00'
        [Parameter(Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, 
        Position = 0)]
        [string]$OlaUserDiffStartTime ,
        # The interval between the Ola Hallengrens Log Backups
        # If 15 minutes this will be 15 if 3 hours this will be 3
        [Parameter(Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, 
        Position = 0)]
        [int32]$OlaUserLogSubDayInterval ,
        # The retention time for User Diff backups
        [Parameter(Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, 
        Position = 0)]
        [int]$OlaUserDiffRetention,

        # The unit of time for the Ola Hallengrens Log Backups interval
        # If 15 minutes this will be Minute if 3 hours this will be Hour
        [Parameter(Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, 
        Position = 0)]
        [string]$OlaUserLoginterval ,
        # The retention time for User Log backups
        [Parameter(Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, 
        Position = 0)]
        [int]$OlaUserLogRetention,

        # The The maximum number of SQL Agent history rows
        [Parameter(Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, 
        Position = 0)]
        [int]$MaximumHistoryRows,
        # The maximium number of rows per job
        [Parameter(Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, 
        Position = 0)]
        [int]$MaximumJobHistoryRows,
        # The Default Fill factor
        [Parameter(Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, 
        Position = 0)]
        [int]$defaultFillFactor
    )

    foreach ($Server in $Servers) {         
        if($Server.Contains('\')) {
            $ServerName = $Server.Split('\')[0]
            $Instance = $Server.Split('\')[1]
        }
        else {
            $Servername = $Server
            $Instance = 'MSSQLSERVER'
        } 

        # make sure the servername is 15 char or less
        $ServerName = $ServerName[0..14] -join "" #.subtring(0, [system.math]::min(15, $ServerName.lengthh))

        ## Check for connectivity
        if((Test-Connection $ServerName -count 1 -Quiet) -eq $false){
            Write-Error "Could not connect to $ServerName"
            $_
            continue
        }
        if ([bool](Test-WSMan -ComputerName $ServerName -ErrorAction SilentlyContinue)) {
        
        }
        else
        {
            Write-Error "PSRemoting is not enabled on $ServerName Please enable and retry"
            continue
        }


        Describe "$Server" {
            BeforeAll {
                $Scriptblock = {

                    [pscustomobject]$Return = @{}
                    $srv = ''
                    $Server = $Using:Server
                    Write-Output $Server
                    [void][reflection.assembly]::LoadWithPartialName('Microsoft.SqlServer.Smo');

                    $srv = New-Object Microsoft.SQLServer.Management.SMO.Server $Server  -ErrorAction SilentlyContinue
                    $Return.SQLRegKey = (Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$Instance" -ErrorAction SilentlyContinue)                    
                    $Return.DBAAdminDb = $Srv.Databases.Name.Contains('DBA-Admin')
                    $Logins = $srv.Logins.Where{$_.IsSystemObject -eq $false}.Name
                    $Return.SQLAdmins = @(Compare-Object $Logins $SQLAdmins -SyncWindow 0).Length - $Logins.count -eq $SQLAdmins.Count
                    $SysAdmins = $Srv.Roles['sysadmin'].EnumMemberNames()
                    $Return.SQLAdmin = @(Compare-Object $SysAdmins $SQLAdmins -SyncWindow 0).Length - $SysAdmins.count -eq $SQLAdmins.Count
                    $Return.BackupDirectory = $srv.BackupDirectory
                    $Return.DataDirectory = $srv.DefaultFile
                    $Return.LogDirectory  = $srv.DefaultLog
                    $Return.MaxMemMb = $srv.Configuration.MaxServerMemory.RunValue
                    $Return.TempFiles = $srv.Databases['tempdb'].FileGroups['PRIMARY'].Files.Count
                    $Return.Collation = $srv.Collation
                    $Return.DatabasesStatus = $srv.Databases.Where{$_.Status -ne 'Normal'}.count
                    $Return.AgentJobs = $srv.JobServer.Jobs.Count
                    $return.OptimizeForAdHoc = $srv.Configuration.OptimizeAdhocWorkloads.RunValue
                    
                    $OlaDbs = 'CommandExecute','DatabaseBackup','DatabaseIntegrityCheck','IndexOptimize'
                    $Sps = $srv.Databases['master'].StoredProcedures.Where{$_.Schema -eq 'dbo'}.Name                     
                    $Return.OlaProcs = @(Compare-Object $sps $oladbs -SyncWindow 1 -ExcludeDifferent -IncludeEqual).Length -eq 4
                    $Return.RestoreProc = $Sps -contains 'RestoreCommand'

                    $job = $srv.JobServer.jobs['DatabaseBackup - SYSTEM_DATABASES - FULL']
                        $Return.OlaSysFullEnabled = $job.IsEnabled
                        $Return.OlaSysFullScheduled = $job.HasSchedule
                        $Return.OlaSysFullFrequency = $job.JobSchedules.FrequencyTypes.ToString()
                        $Return.OlaSysFullStartTime = $job.JobSchedules.ActiveStartTimeOfDay
                        $Return.OlaSysFullRetention = (($job.JobSteps | Where-Object {$_.SubSystem -eq "CmdExec"}).Command.Split("@") | Where-Object {$_ -match "CleanupTime"}).split("=")[1].split(",").split(" ")[1]
                        $Return.OlaSysFullEmail = $job.EmailLevel.ToString()
                        $Return.OlaSysFullEmailOperator = $job.OperatorToEmail

                    $job = $srv.JobServer.jobs['DatabaseBackup - USER_DATABASES - FULL']
                        $Return.OlaUserFullEnabled = $job.IsEnabled
                        $Return.OlaUserFullScheduled = $job.HasSchedule
                        $Return.OlaUserFullSchedule = $job.JobSchedules.FrequencyTypes.ToString()
                        $Return.OlaUserFullFrequency = $job.JobSchedules.FrequencyInterval
                        $Return.OlaUserFullStartTime = $job.JobSchedules.ActiveStartTimeOfDay 
                        $Return.OlaUserFullRetention = (($job.JobSteps | Where-Object {$_.SubSystem -eq "CmdExec"}).Command.Split("@") | Where-Object {$_ -match "CleanupTime"}).split("=")[1].split(",").split(" ")[1]
                        $Return.OlaUserFullEmail = $job.EmailLevel.ToString()
                        $Return.OlaUserFullEmailOperator = $job.OperatorToEmail

                    $job = $srv.JobServer.jobs['DatabaseBackup - USER_DATABASES - DIFF']
                        $Return.OlaUserDiffEnabled = $job.IsEnabled 
                        $Return.OlaUserDiffScheduled = $job.HasSchedule
                        $Return.OlaUserDiffSchedule = $job.JobSchedules.FrequencyTypes.ToString()
                        $Return.OlaUserDiffFrequency = $job.JobSchedules.FrequencyInterval
                        $Return.OlaUserDiffStartTime = $job.JobSchedules.ActiveStartTimeOfDay
                        $Return.OlaUserDiffRetention = (($job.JobSteps | Where-Object {$_.SubSystem -eq "CmdExec"}).Command.Split("@") | Where-Object {$_ -match "CleanupTime"}).split("=")[1].split(",").split(" ")[1]
                        $Return.OlaUserDiffEmail = $job.EmailLevel.ToString()
                        $Return.OlaUserDiffEmailOperator = $job.OperatorToEmail

                    $job = $srv.JobServer.jobs['DatabaseBackup - USER_DATABASES - Log']
                        $Return.OlaUserLogEnabled = $job.IsEnabled 
                        $Return.OlaUserLogScheduled = $job.HasSchedule
                        $Return.OlaUserLogSchedule = $job.JobSchedules.FrequencyTypes.ToString()
                        $Return.OlaUserLogFrequency = $job.JobSchedules.FrequencyInterval
                        $Return.OlaUserLogSubDayInterval = $job.JobSchedules.FrequencySubDayInterval
                        $Return.OlaUserLoginterval = $job.JobSchedules.FrequencySubDayTypes.ToString()
                        $Return.OlaUserLogRetention = (($job.JobSteps | Where-Object {$_.SubSystem -eq "CmdExec"}).Command.Split("@") | Where-Object {$_ -match "CleanupTime"}).split("=")[1].split(",").split(" ")[1]
                        $Return.OlaUserLogEmail = $job.EmailLevel.ToString()
                        $Return.OlaUserLogEmailOperator = $job.OperatorToEmail

                    $job = $srv.JobServer.jobs['CommandLog Cleanup']
                        $Return.OlaCommandLogCleanupEnabled = $job.IsEnabled 
                        $Return.OlaCommandLogCleanupScheduled = $job.HasSchedule
                        $Return.OlaCommandLogCleanupEmail = $job.EmailLevel.ToString()
                        $Return.OlaCommandLogCleanupEmailOperator = $job.OperatorToEmail

                    $job = $srv.JobServer.jobs['DatabaseIntegrityCheck - SYSTEM_DATABASES']
                        $Return.OlaSystemDatabaseIntegrityCheckEnabled = $job.IsEnabled 
                        $Return.OlaSystemDatabaseIntegrityCheckScheduled = $job.HasSchedule
                        $Return.OlaSystemDatabaseIntegrityCheckEmail = $job.EmailLevel.ToString()
                        $Return.OlaSystemDatabaseIntegrityCheckEmailOperator = $job.OperatorToEmail

                    $job = $srv.JobServer.jobs['DatabaseIntegrityCheck - USER_DATABASES']
                        $Return.OlaUserDatabaseIntegrityCheckEnabled = $job.IsEnabled 
                        $Return.OlaUserDatabaseIntegrityCheckScheduled = $job.HasSchedule
                        $Return.OlaUserDatabaseIntegrityCheckEmail = $job.EmailLevel.ToString()
                        $Return.OlaUserDatabaseIntegrityCheckEmailOperator = $job.OperatorToEmail

                    $job = $srv.JobServer.jobs['IndexOptimize - USER_DATABASES']
                        $Return.OlaUserDatabaseIndexOptimizeEnabled = $job.IsEnabled 
                        $Return.OlaUserDatabaseIndexOptimizeScheduled = $job.HasSchedule
                        $Return.OlaUserDatabaseIndexOptimizeEmail = $job.EmailLevel.ToString()
                        $Return.OlaUserDatabaseIndexOptimizeEmailOperator = $job.OperatorToEmail

                    $job = $srv.JobServer.jobs['Output File Cleanup']
                        $Return.OlaOutputFileCleanupEnabled = $job.IsEnabled 
                        $Return.OlaOutputFileCleanupScheduled = $job.HasSchedule
                        $Return.OlaOutputFileCleanupEmail = $job.EmailLevel.ToString()
                        $Return.OlaOutputFileCleanupEmailOperator = $job.OperatorToEmail

                    $job = $srv.JobServer.jobs['sp_delete_backuphistory']
                        $Return.OlaDeleteBackupHistoryEnabled = $job.IsEnabled 
                        $Return.OlaDeleteBackupHistoryScheduled = $job.HasSchedule
                        $Return.OlaDeleteBackupHistoryEmail = $job.EmailLevel.ToString()
                        $Return.OlaDeleteBackupHistoryEmailOperator = $job.OperatorToEmail

                    $job = $srv.JobServer.jobs['sp_purge_jobhistory']
                        $Return.OlaPurgeJobHistoryEnabled = $job.IsEnabled 
                        $Return.OlaPurgeJobHistoryScheduled = $job.HasSchedule
                        $Return.OlaPurgeJobHistoryEmail = $job.EmailLevel.ToString()
                        $Return.OlaPurgeJobHistoryEmailOperator = $job.OperatorToEmail 
                    
                    $Return.HasSPBlitz = $Srv.Databases['master'].StoredProcedures.Name -contains 'sp_blitz'
                    $Return.HasSPBlitzCache = $Srv.Databases['master'].StoredProcedures.Name -contains 'sp_blitzCache'
                    $Return.HasSPBlitzIndex = $Srv.Databases['master'].StoredProcedures.Name -contains 'sp_blitzIndex'
                    $Return.HasSPAskBrent = $Srv.Databases['master'].StoredProcedures.Name -contains 'sp_AskBrent'
                    $Return.HASSPBlitzTrace = $Srv.Databases['master'].StoredProcedures.Name -contains 'sp_BlitzTrace'
                    $Return.HasSPWhoisActive = $Srv.Databases['master'].StoredProcedures.Name -contains 'sp_WhoIsActive'
                    $Return.LogWhoIsActiveToTable = $srv.JobServer.jobs.name.Contains('Log SP_WhoisActive to Table')
                    $Return.LogSPBlitzToTable = $srv.JobServer.jobs.name.Contains('Log SP_Blitz to table')
                    $Return.LogSPBlitzToTableEnabled = $srv.JobServer.jobs['Log SP_Blitz to table'].IsEnabled
                    $Return.LogSPBlitzToTableScheduled = $srv.JobServer.jobs['log SP_Blitz to table'].HasSchedule
                    $Return.LogSPBlitzToTableSchedule = $srv.JobServer.jobs['Log SP_Blitz to table'].JobSchedules.FrequencyTypes
                    $Return.LogSPBlitzToTableFrequency = $srv.JobServer.jobs['Log SP_Blitz to table'].JobSchedules.FrequencyInterval
                    $Return.LogSPBlitzToTableStartTime = $srv.JobServer.jobs['Log SP_Blitz to table'].JobSchedules.ActiveStartTimeOfDay
                    $Return.Alerts20SeverityPlusExist = $srv.JobServer.Alerts.Where{$_.Severity -ge 20}.Count
                    $Return.Alerts20SeverityPlusEnabled = $srv.JobServer.Alerts.Where{$_.Severity -ge 20 -and $_.IsEnabled -eq $true}.Count
                    $Return.Alerts82345Exist = ($srv.JobServer.Alerts |
                        Where-Object {$_.Messageid -eq 823 -or $_.Messageid -eq 824 -or $_.Messageid -eq 825}).Count
                    $Return.Alerts82345Enabled = ($srv.JobServer.Alerts |
                        Where-Object {$_.Messageid -eq 823 -or $_.Messageid -eq 824 -or $_.Messageid -eq 825 -and $_.IsEnabled -eq $true}).Count
                    $Return.SysDatabasesFullBackupToday = $srv.Databases.Where{$_.IsSystemObject -eq $true -and $_.Name -ne 'tempdb' -and $_.LastBackupDate -lt (Get-Date).AddDays(-1)}.Count                               

                    # Server Triggers
                    $return.DatabaseAlteredTriggerExist = $srv.Triggers.Contains("DDL_Database_ALTERED_Trigger")
                    $return.DatabaseAlteredTriggerEnabled = $srv.Triggers["DDL_Database_ALTERED_Trigger"].IsEnabled
                    $return.DatabaseAttemptedDropTriggerExist = $srv.Triggers.Contains("DDL_Database_Attemped_DROP_Trigger")
                    $return.DatabaseAttemptedDropTriggerEnabled = $srv.Triggers["DDL_Database_Attemped_DROP_Trigger"].IsEnabled
                    $return.DatabaseDroppedTriggerExist = $srv.Triggers.Contains("DDL_Database_DROPPED_Trigger")
                    $return.DatabaseDroppedTriggerEnabled = $srv.Triggers["DDL_Database_DROPPED_Trigger"].IsEnabled

                    #System Stored procedures
                    $return.HasHelpRevLoginMod = $srv.Databases['master'].StoredProcedures.name -contains 'sp_help_revlogin_mod'
                    $return.HasHelpRevLoginMod = $srv.Databases['master'].StoredProcedures.name -contains 'sp_hexadecimal'
                    $return.HasHelpRevLoginMod = $srv.Databases['master'].StoredProcedures.name -contains 'sp_who3'
                    $return.HasHelpRevLoginMod = $srv.Databases['master'].StoredProcedures.name -contains 'sp_help_revlogin_mod'

                    # File Structure
                    $return.DataVolumeName = (Get-WmiObject Win32_logicaldisk | Where-Object {$_.DeviceID -eq 'J:' }).volumename
                    $return.LogVolumeName = (Get-WmiObject Win32_logicaldisk | Where-Object {$_.DeviceID -eq 'K:' }).volumename
                    $return.TempDBVolumeName = (Get-WmiObject Win32_logicaldisk | Where-Object {$_.DeviceID -eq 'L:' }).volumename

                    #Server Defaults
                    $return.BackupCompressionEnabled = $srv.VersionMajor -ge 10 -and $srv.Configuration.DefaultBackupCompression.ConfigValue -eq $true
                    $Return.BlockProcessThreshold = $srv.Configuration.BlockedProcessThreshold.ConfigValue 
                    $Return.DefaultFillFactor = $srv.Configuration.FillFactor.ConfigValue 
                    $return.DefaultTraceEnabled = $srv.Configuration.DefaultTraceEnabled.ConfigValue -eq $true
                    $return.XPCommandShellEnabled = $srv.Configuration.XPCmdShellEnabled.ConfigValue -eq $true
                    $return.DACEnabled = $srv.Configuration.RemoteDacConnectionsEnabled.ConfigValue -eq $true
                    $return.OLEAutomationEnabled = $srv.Configuration.OleAutomationProceduresEnabled.ConfigValue -eq $true

                    # Operating System
                    $return.PowerPlan = Get-WmiObject -Class Win32_PowerPlan -Namespace "root\cimv2\power" -ErrorAction SilentlyContinue | 
                        Where-Object {$_.IsActive -eq $true} |
                        Select-Object -ExpandProperty ElementName

                    # PowerShell
                    $return.CurrentPowerShellVersion = $PSVersionTable.PSVersion -gt "5.0.0.0"
                    $return.DBAToolsVersion = (Get-Module dbatools).Version 
                    
                    #Model datbase sizes and autogrowth
                    $modeldb = $srv.Databases['model']
                    $return.ModelDataFileSize = $modeldb.FileGroups['primary'].Files[0].Size -eq 1MB
                    $return.ModelDataFileGrowth = $modeldb.FileGroups['primary'].Files[0].Growth -eq 1MB
                    $return.ModelLogFileSize = $modeldb.LogFiles[0].Size -eq 512kb
                    $return.ModelLogFileGrowth = $modeldb.LogFiles[0].Growth -eq 512kb

                    # SQL Agent
                    $return.MaximumHistoryRows = $srv.JobServer.MaximumHistoryRows 
                    $return.MaximumJobHistoryRows = $srv.JobServer.MaximumJobHistoryRows 

                    # Databases 
                    $return.DatabasesWithMoreThanOneLogFile = ($srv.Databases  | Where-Object {$_.logfiles.count -gt 1}).count
                                           
                    return $return
                }
                $return = Invoke-Command -ScriptBlock $Scriptblock -ComputerName $ServerName -ErrorAction SilentlyContinue
            } # BeforeAll

            Context 'Server' {
                It 'Should Exist and respond to ping' {
                    $connect = Test-Connection $ServerName -count 1 -Quiet 
                    $Connect|Should Be $true
                } 
                if($connect -eq $false){break}

                It 'Should have SQL Server Installed' -Skip{  
                    $Return.SQLRegKey | Should Be $true
                }

            } # End Context     
            
            Context 'Services' {
                BeforeAll {
                    If($Instance -eq 'MSSQLSERVER') {
                        $SQLService = $Instance
                        $AgentService = 'SQLSERVERAGENT'
                    }
                    else {
                        $SQLService = "MSSQL$" + $Instance
                        $AgentService = "SQLAgent$" + $Instance
                        }
                    $MSSQLService = (Get-CimInstance -ClassName Win32_Service -Filter "Name = '$SQLService'" -CimSession $ServerName)
                    $SQLAgentService = (Get-CimInstance -ClassName Win32_Service -Filter "Name = '$AgentService'" -CimSession $ServerName)
                }

                It 'SQL DB Engine should be running' {
                    $MSSQLService.State | Should Be 'Running'
                }
                It 'SQL Db Engine should be Automatic Start' {
                    $MSSQLService.StartMode |should be 'Auto'
                }
                It 'SQL Agent should be running' {
                    $SQLAgentService.State | Should Be 'Running'
                }
                It 'SQL Agent should be Automatic Start' {
                    $SQLAgentService.StartMode |should be 'Auto'
                }            
            }  # Context 'Services' 

            Context 'Databases' {
                <#It 'Should have a DBA-Admin Database' {
                    $Return.DbaAdminDB |Should Be $true
                }#>
                It 'Databases should have a normal Status - No Restoring, Recovery Pending etc' {
                    $Return.DatabasesStatus |Should Be 0
                }
                
                It 'System Databases Should have been backed up within the last 24 hours' {
                    $Return.SysDatabasesFullBackupToday | Should be 0 -ErrorAction SilentlyContinue
                }

                it 'No databases should have more than one log file' {
                    $return.DatabasesWithMoreThanOneLogFile | Should be 0
                }
            } # Context 'Databases'   

            Context 'Operating System' {
                it "The server power plan should be set to 'High Performance'" {
                    $return.powerplan | should be "High performance"
                }
            } # Context 'Operating System' 
            
            Context 'Server Defaults' {
                It "Should have a default Data Directory of $DataDirectory" {
                    $Return.DataDirectory |Should MatchExactly ([regex]::Escape("$($DataDirectory)"))
                }
                It "Should have a default Log Directory of $LogDirectory " {
                    $Return.LogDirectory |Should MatchExactly ([regex]::Escape("$($LogDirectory)"))
                }
                it 'Backup compression shold be enabled '{
                    $return.BackupCompressionEnabled | should be $true    
                }
                it 'Blocked Process Threshold should be 5' {
                    $Return.BlockProcessThreshold | should be 5
                }                 
                it "Default fill factor should be $($defaultFillFactor)" {
                    $Return.DefaultFillFactor | should be $defaultFillFactor
                }
                it "Default trace should be enabled" {
                    $return.DefaultTraceEnabled | should be $true
                }
                it "XP Command shell should be enabled" {
                    $return.XPCommandShellEnabled | should be $true
                }
                it "Remote DAC should be enabled" {
                    $return.DACEnabled | should be $true
                }
                it "OLE Automation should be enabled" {
                    $return.OLEAutomationEnabled | should be $true
                }
                It "Optimize for Ad Hoc workloads should be enabled" {
                    $return.OptimizeForAdHoc | should be 1
                }
            }  
            
            context 'Model database settings' {
                It "The Model data file size should be 1GB" {
                    $Return.ModelDataFileSize | Should be $true
                }
                it "The Model data file autogrowth should be 1GB"{
                    $Return.ModelDataFileGrowth | should be $true
                }
                It "The Model log file size should be 512MB" {
                    $Return.ModelLogFileSize | Should be $true
                }
                it "The Model log file autogrowth should be 512MB"{
                    $Return.ModelLogFileGrowth | should be $true
                }
            } # context Model database settings   

            Context 'Ola Hallengren' {
                It 'Should have Ola Hallengrens maintenance Solution' {
                    $Return.OlaProcs | Should Be $True
                }
                It 'Should have Restore Proc for Ola Hallengrens Maintenance Solution' -Skip  {
                    $Return.RestoreProc | Should Be $True
                }

                # System Backups
                It 'The Full System Database Backup should be enabled' {
                    $Return.OlaSysFullEnabled | Should Be $True
                }
                It 'The Full System Database Backup should be scheduled' {
                    $Return.OlaSysFullScheduled | Should Be $True
                }
                It "The Full System Database Backup should be scheduled $OlaSysFullFrequency" {
                    $Return.OlaSysFullFrequency| Should Be $OlaSysFullFrequency 
                }
                It "The Full System Database Backup should be scheduled at $OlaSysFullStartTime" -Skip {
                    $Return.OlaSysFullStartTime| Should Be $OlaSysFullStartTime
                }
                It "The Full System Database Backup retention should be $OlaSysFullRetention " {
                    $Return.OlaSysFullRetention | should be $OlaSysFullRetention
                }
                It "The full System Database backup should email failures" {
                    $Return.OlaSysFullEmail | Should be "OnFailure"
                }
                It "The full System Database backup should email failures to 'DBA - Team'" {
                    $Return.OlaSysFullEmailOperator | Should be "DBA - Team"
                }

                # Full User backups
                It 'The Full User Database Backup should be enabled' {     
                    $Return.OlaUserFullEnabled| Should Be $True
                }
                It 'The Full User Database Backup should be scheduled' {
                    $Return.OlaUserFullScheduled | Should Be $True
                }
                It "The Full User Database Backup should be scheduled $OlaUserFullSchedule" {
                    $Return.OlaUserFullSchedule | Should Be $OlaUserFullSchedule
                }
                It "The Full user Database Backup should be scheduled Weekly on a $OlaUserFullFrequency" {
                    $Return.OlaUserFullFrequency| Should Be $OlaUserFullFrequency
                }
                It "The Full User Database Backup should be scheduled at $OlaUserFullStartTime" -Skip {
                    $return.OlaUserFullStartTime| Should Be $OlaUserFullStartTime
                }
                It "The Full User Database Backup retention should be $OlaUserFullRetention " {
                    $Return.OlaUserFullRetention | should be $OlaUserFullRetention
                }
                It "The full User Database backup should email failures" {
                    $Return.OlaUserFullEmail | Should be "OnFailure"
                }
                It "The full User Database backup should email failures to 'DBA - Team'" {
                    $Return.OlaUserFullEmailOperator | Should be "DBA - Team"
                }

                # Diff backup
                It 'The Diff User Database Backup should be enabled' {
                    $Return.OlaUserDiffEnabled| Should Be $True
                }
                It 'The Diff User Database Backup should be scheduled' {
                    $Return.OlaUserDiffScheduled| Should Be $True
                }
                It "The Diff User Database Backup should be scheduled Daily Except Sunday = $OlaUserDiffSchedule" {
                    $Return.OlaUserDiffSchedule| Should Be $OlaUserDiffSchedule
                }
                It "The Diff User Database Backup should be scheduled Daily Except Sunday = $OlaUserDiffFrequency" {
                    $Return.OlaUserDiffFrequency| Should Be $OlaUserDiffFrequency
                }
                It "The Diff User Database Backup should be scheduled at $OlaUserDiffStartTime" -Skip {
                    $Return.OlaUserDiffStartTime| Should Be $OlaUserDiffStartTime 
                }
                It "The Diff User Database Backup retention should be $OlaUserDiffRetention " {
                    $Return.OlaUserDiffRetention | should be $OlaUserDiffRetention
                }
                It "The Diff User Database backup should email failures" {
                    $Return.OlaUserDiffEmail | Should be "OnFailure"
                }
                It "The Diff User Database backup should email failures to 'DBA - Team'" {
                    $Return.OlaUserDiffEmailOperator | Should be "DBA - Team"
                }

                # Log Backup
                It 'The Log User Database Backup should be enabled' {
                    $Return.OlaUserLogEnabled| Should Be $true
                }
                It 'The Log User Database Backup should be scheduled' {
                    $Return.OlaUserLogScheduled| Should Be $True
                }
                It 'The Log User Database Backup should be scheduled Daily' {
                    $Return.OlaUserLogSchedule  | Should Be 'Daily'
                }
                It 'The Log User Database Backup should be scheduled Daily' {
                    $Return.OlaUserLogFrequency| Should Be 1
                }
                It "The Log User Database Backup should be scheduled for every $OlaUserLogSubDayInterval" {
                    $Return.OlaUserLogSubDayInterval| Should Be $OlaUserLogSubDayInterval
                }
                It "The Log User Database Backup should be scheduled for every $OlaUserLoginterval" {
                    $Return.OlaUserLoginterval| Should Be $OlaUserLoginterval 
                }
                It "The Log User Database Backup retention should be $OlaUserLogRetention " {
                    $Return.OlaUserFullRetention | should be $OlaUserLogRetention
                }
                It "The Log User Database backup should email failures" {
                    $Return.OlaUserLogEmail | Should be "OnFailure"
                }
                It "The Log User Database backup should email failures to 'DBA - Team'" {
                    $Return.OlaUserLogEmailOperator | Should be "DBA - Team"
                }
                              
                                
                $jobnames = @()
                $jobnames += "Purge Job History"
                $jobnames += "Delete Backup History"
                $jobnames += "Output File Cleanup"
                $jobnames += "User Database Index Optimize"
                $jobnames += "User Database Integrity Check"
                $jobnames += "System Database Integrity Check"
                $jobnames += "Command Log Cleanup"
                #$jobnames += ""

                foreach ($jobname in ($jobnames | Sort-Object -Unique)) {
                    It "The $($jobname) should be enabled" {
                        $Return."Ola$($jobname.Replace(' ', ''))Enabled" | Should Be $true
                    }
                    It "The $($jobname) should be scheduled" {
                        $Return."Ola$($jobname.Replace(' ', ''))Scheduled" | Should Be $True 
                    }
                    It "The $($jobname) should email failures" {
                        $Return."Ola$($jobname.Replace(' ', ''))Email" | Should be "OnFailure"
                    }
                    It "The $($jobname) should email failures to 'DBA - Team'" {
                        $Return."Ola$($jobname.Replace(' ', ''))EmailOperator" | Should be "DBA - Team"
                    }
                }

            }
            
            Context "Trace Flags" {

                $srv = New-Object Microsoft.SQLServer.Management.SMO.Server $Server  -ErrorAction SilentlyContinue
                $StartupParams = Get-DbaStartupParameter $server 
                #$return | Add-Member TraceFlags $StartupParams.TraceFlags                
                $Trace1118Set = (($StartupParams.TraceFlags -split "," | Where-Object {$_ -eq "1118"}).count -gt 0 -or $srv.VersionMajor -ge 13)
                $Trace2371Set = (($StartupParams.TraceFlags -split "," | Where-Object {$_ -eq "2371"}).count -gt 0 -or $srv.VersionMajor -ge 13)
                $Trace3226Set = (($StartupParams.TraceFlags -split "," | Where-Object {$_ -eq "3226"}).count -gt 0)

                #$return.TraceFlags = $StartupParams.TraceFlags
                #$return.Trace1118Set = ($StartupParams.TraceFlags -split "," | Where-Object {$_ -eq "-t1118"}).count -gt 0 #-or $srv.VersionMajor -ge 13
                #$return.Trace2371Set = ($StartupParams.TraceFlags -split "," | Where-Object {$_ -eq "-t2371"}).count -gt 0 -or $srv.VersionMajor -ge 13
                #$return.Trace3226Set = ($StartupParams.TraceFlags -split "," | Where-Object {$_ -eq "-t3226"}).count -gt 0                

                # Trace Flags
                it "Trace flags should not be empty" {
                    $StartupParams.TraceFlags  | should not be "None" 
                }
                It "Startup trace flag T1118" {
                       $Trace1118Set | Should be $true
                }
                It "Startup trace flag T2371" {
                       $Trace2371Set | Should be $true
                }
                It "Startup trace flag T3226" {
                       $Trace3226Set | Should be $true
                }
            }   

            Context "SQL Agent Settings" {
                it "The maximum number of history rows should be at least $($MaximumHistoryRows)" {
                    $return.MaximumHistoryRows | should BeGreaterThan ($MaximumHistoryRows - 1)
                }
                it "The maximum number of rows per job should be at least $($MaximumJobHistoryRows)" {
                    $return.MaximumJobHistoryRows | should BeGreaterThan ($MaximumJobHistoryRows - 1)
                }
            }

            Context "SQL Agent Jobs" {
                BeforeAll {
                    $jobinfo = $server | Find-DbaAgentJob
                }
                
                It "Should not have any uncategorized jobs" {
                    ($jobinfo | Where-Object {$_.Category -eq '[Uncategorized (Local)]'}).count | should not begreaterthan 0                    
                }
                It "Should not have any jobs without descriptions" {
                    ($jobinfo.job | Where-Object {$_.Description -eq 'No description available.'}).count | should not begreaterthan 0
                }
                It "Should not have any disabled jobs that haven't been ran in 6 months" {
                    ($jobinfo.job |
                        Where-Object {$_.Isenabled -eq $false } | 
                        Where-Object {(New-TimeSpan $_.LastRunDate $(get-date)).TotalDays -gt 180 } |
                        Where-Object {$_.description -eq "Source: https://ola.hallengren.com"}).count | should not begreaterthan 0
                }
            }

            Context "Server Triggers" {
                it "Should have DDL_Database_ALTERED_Trigger" {
                    $return.DatabaseAlteredTriggerExist | Should be $true
                }
                
                it "Should have DDL_Database_Attemped_DROP_Trigger" {
                    $return.DatabaseAttemptedDropTriggerExist | Should be $true
                }

                it "Should have DDL_Database_DROPPED_Trigger" {
                    $return.DatabaseDroppedTriggerExist | Should be $true
                }
                
                <#                    
                    $return.DatabaseAlteredTriggerEnabled = $srv.Triggers["DDL_Database_ALTERED_Trigger"].IsEnabled                    
                    $return.DatabaseAttemptedDropTriggerEnabled = $srv.Triggers["DDL_Database_Attemped_DROP_Trigger"].IsEnabled
                    $return.DatabaseDroppedTriggerEnabled = $srv.Triggers["DDL_Database_DROPPED_Trigger"].IsEnabled
                #>

            } # Context "Server triggers"

            Context "PowerShell Environment" {
                It "Should have at least version 5.0.0.0 of PowerShell installed" {
                    $return.CurrentPowerShellVersion | Should be $true
                }
                it "Should have at least version 0.8.957 of dbatools installed" -Skip {
                    $return.DBAToolsVersion | should be 0.8.957
                }
            }

            Context "File Structure" {
                $freespace = $server | Get-DbaDatabaseSpace |
                    where-object {-not ($_.PhysicalName -like "J:\SQLServer\Data\*" -and ($_.PhysicalName -match ".mdf" -or $_.PhysicalName -match ".ndf"))} |
                    Where-Object { ($_.FileType -notlike "FULLTEXT") } |
                    Where-Object {-not ($_.PhysicalName -like "K:\SQLServer\Log\*" -and ($_.PhysicalName -match ".ldf"))} |
                    where-object {-not ($_.Database -eq "ReportServer")} |    
                    where-object {-not ($_.Database -eq "ReportServerTempDB")} 
    
                It "Must have no files in non standard locations" {
                    $freespace.count | should be 0
                }
                It "Must have no MB in non standard locations" {
                    ($freespace | Measure-Object FileSizeMB -Sum).Sum | should not BeGreaterThan 0 
                }
                It "Must have the correct data volume name " {
                    $return.DataVolumeName | Should MatchExactly "SQL Data"    
                }
                It "Must have the correct log volume name " {
                    $return.LogVolumeName | Should MatchExactly "SQL Log"    
                }
                It "Must have the correct TempDB volume name " {
                    $return.TempDBVolumeName | Should MatchExactly "SQL TempDB"    
                }                
            }

            Context "TempDB" {
                BeforeAll {
                    $srv = New-Object Microsoft.SQLServer.Management.SMO.Server $Server
                    $tempdb = $srv.Databases['tempdb']
                }
                
                It "TempDB Log file should be set to grow by at least 512 MB" {
                    ($tempdb.LogFiles | Where-Object {$_.growth -lt 512kb}).count | should be 0
                }

                it "TempDB data files should be set to grow  by at least 512 MB" {                     
                    ($tempdb.FileGroups[0].files | Where-Object {$_.growth -lt 512kb}).count | should be 0
                }
            }

        } # Describe "$Server" 

    } # foreach ($Server in $Servers)

#} # function Test-SQLDefaults

#Test-SQLDefaults "tog-sql"


<#
Describe "Testing ASH SQLServers" {
    Context "SQL State"{
    
        foreach ($server in $servers) {
           $DBEngine = Get-service -ComputerName $Server -Name MSSQLSERVER
           It "$Server DBEngine should be running" {
                $DBEngine.Status | Should Be 'Running'
            }
           It "$server DBEngine Should be Auto Start" {
            $DBEngine.StartType | Should be 'Automatic'
           }
              $Agent= Get-service -ComputerName $Server -Name SQLSERVERAGENT
              It "$Server Agent should be running" {
                  $Agent.Status | Should Be 'Running'
           }
           It "$Server Agent Should be Auto Start" {
            $Agent.StartType | Should be 'Automatic'
           }       

        }
    } 
      
}     
#>