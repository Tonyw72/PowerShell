Function Ola-List {
    [cmdletbinding()]
    param ( 
        [String] $CMSServerName = "TOG-SQL",
        [String[]] $ServerGroups,
        [String[]] $ServerList
    )
    

    $connectionString = "data source=$CMSServerName;initial catalog=master;integrated security=sspi;" 
    $sqlConnection = New-Object ("System.Data.SqlClient.SqlConnection") $connectionstring 
    $conn = New-Object ("Microsoft.SQLServer.Management.common.serverconnection") $sqlconnection 
    $cmsStore = New-Object ("Microsoft.SqlServer.Management.RegisteredServers.RegisteredServersStore") $conn 
    $cmsRootGroup = $cmsStore.ServerGroups["DatabaseEngineServerGroup"].ServerGroups       
    
    #$servers = $cmsRootGroup.RegisteredServers #| gm
    $servers = $cmsRootGroup.RegisteredServers | Sort-Object -property servername -unique  #| gm
    
    $olajobs = @()
    $i=0

    $serverList = @("ash-stg1", "ash-stgsql", "ash-stgsql-kfax", "ash-stgsqlcms", "sd-ashbstg", "stg-desktop", `
        "stg-hrlrep08", "stgsql-ashlink8", "sql-hrtest08", "ashbi-qa1", "ashbi-qa2", "ash_dev", "ashb-dev", "ashlink-dev08", `
        "dev-ashlink12")

    #foreach ($svr in $servers | where {$_.Servername -eq "ASHB-DEV" -or $_.Servername -eq "ASHB-SQL" -or $_.ServerName -eq "HYLAND-SQL1"}) {
    foreach($svr in $servers | where {$serverList -contains $_.Servername}) {
    #foreach ($svr in $servers) {

        #$servers |  Sort-Object -property servername -unique | foreach { 
    
        $server  = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $svr.Servername   
        $i += 1
        Write-Progress -Activity "Processing $($server.name)" -PercentComplete ($i/$servers.Count*100)
        
        #if ($server.JobServer.Jobs.count -ge 100) {continue;}
                        
        "$($server.Name) `t # of SQL AgentJobs $($server.JobServer.Jobs.count)"

        $jobs = $server.JobServer.Jobs | where {$_.Description -like "*ola.hallengren.com*" -and $_.name -like "DatabaseBackup*"} 

        if ($jobs.count -eq 0) {
            $properties = @{
                Server = $server.Name;
                Jobname = "";
                Enabled = $false;
                Databases = "";
                Directory = "";
                BackupType = "";
                Verify = "";
                Checksum = "";
                LogToTable = "";
                CleanupTime = "";  
                NumSchedules =  "";                 
                SchdEnabled = "";
                Frequency = "";
                Interval = "";
                LastRunOutcome = ""
                }
            $ola = New-Object psobject -Property $properties
            $olajobs += $ola
            #continue
        }

        foreach ($job in $server.JobServer.Jobs | where {$_.Description -like "*ola.hallengren.com*" -and $_.name -like "DatabaseBackup*"}) {

            # Get the step information
            foreach ($step in $job.JobSteps | where {$_.SubSystem -eq "CmdExec"}) {
                foreach ($item in $step.Command.Split("@")) {
                    $itemset = $item.split("=")

                    if ($itemset[0] -match "Databases") {$databases = $itemset[1].split("'")[1]}
                    if ($itemset[0] -match "Directory") {$directory = $itemset[1].split("'")[1]}
                    if ($itemset[0] -match "BackupType") {$backuptype = $itemset[1].split("'")[1]}
                    if ($itemset[0] -match "Verify") {$verify = $itemset[1].split("'")[1]}
                    if ($itemset[0] -match "Checksum") {$checksum = $itemset[1].split("'")[1]}
                    if ($itemset[0] -match "LogToTable") {$logtotable = $itemset[1].split("'")[1]}
                    if ($itemset[0] -match "CleanupTime") {$CleanupTime = $itemset[1].split(",").split(" ")[1]}
                } # foreach ($item in $step.Command.Split("@"))

                if($job.JobSchedules.Count -eq 0) {
                    $properties = @{
                        Server = $server.Name;
                        Jobname = $job.Name;
                        Enabled = $Job.IsEnabled;
                        Databases = $databases;
                        Directory = $directory;
                        BackupType = $backuptype;
                        Verify = $verify;
                        Checksum = $checksum;
                        LogToTable = $logtotable;
                        CleanupTime = $CleanupTime;  
                        NumSchedules =  $job.JobSchedules.Count;                 
                        SchdEnabled = "";
                        Frequency = "";
                        Interval = "";
                        LastRunOutcome = ""
                        }
                    $ola = New-Object psobject -Property $properties
                    $olajobs += $ola
                }

                write-out "$($Server.name) - $($job.Name): $($job.LastRunOutcome)"

                foreach ($schd in $job.JobSchedules | where {$_.isenabled -eq $true}) {
                    $properties = @{
                        Server = $server.Name;
                        Jobname = $job.Name;
                        Enabled = $Job.IsEnabled;
                        Databases = $databases;
                        Directory = $directory;
                        BackupType = $backuptype;
                        Verify = $verify;
                        Checksum = $checksum;
                        LogToTable = $logtotable;
                        CleanupTime = $CleanupTime;  
                        NumSchedules =  $job.JobSchedules.Count;                 
                        SchdEnabled = $schd.isenabled.tostring();
                        Frequency = $schd.FrequencyTypes.tostring();
                        Interval = "";
                        LastRunOutcome = $job.LastRunOutcome
                        }
                                        
                    #"`t$($job.Name) - $($schd.FrequencyTypes.tostring()) - $($schd.FrequencySubDayTypes) - $($schd.FrequencySubDayInterval) - $($schd.FrequencyRelativeIntervals) - $($schd.FrequencyRecurrenceFactor) - $($startTime)  "

                    if ($schd.FrequencyTypes.tostring() -eq "weekly") {
                        IF ($schd.FrequencyInterval -band [Microsoft.SqlServer.Management.Smo.Agent.WeekDays]::Sunday) { $properties.Interval += 'Sunday '}
                        IF ($schd.FrequencyInterval -band [Microsoft.SqlServer.Management.Smo.Agent.WeekDays]::Monday) { $properties.Interval += 'Monday '}
                        IF ($schd.FrequencyInterval -band [Microsoft.SqlServer.Management.Smo.Agent.WeekDays]::Tuesday) { $properties.Interval += 'Tuesday '}
                        IF ($schd.FrequencyInterval -band [Microsoft.SqlServer.Management.Smo.Agent.WeekDays]::Wednesday) { $properties.Interval += 'Wednesday '}
                        IF ($schd.FrequencyInterval -band [Microsoft.SqlServer.Management.Smo.Agent.WeekDays]::Thursday) { $properties.Interval += 'Thursday '}
                        IF ($schd.FrequencyInterval -band [Microsoft.SqlServer.Management.Smo.Agent.WeekDays]::Friday) { $properties.Interval += 'Friday '}
                        IF ($schd.FrequencyInterval -band [Microsoft.SqlServer.Management.Smo.Agent.WeekDays]::Saturday) { $properties.Interval += 'Saturday '}
                    }

                    if ($schd.FrequencySubDayTypes -eq 'Once') {
                        $properties.Interval += "@ $("{0:c}" -f $schd.ActiveStartTimeOfDay)"
                    }
                    Else {
                        $properties.Interval += "every $($schd.FrequencySubDayInterval) $($schd.FrequencySubDayTypes)s"
                    }

                    $ola = New-Object psobject -Property $properties
                    $olajobs += $ola                    

                } # foreach ($schd in $job.JobSchedules | where {$_.isenabled -eq $true})

            } # foreach ($step in $job.JobSteps | where {$_.SubSystem -eq "CmdExec"})            

        } # foreach ($job in $server.JobServer.Jobs | where {$_.Description -like "*ola.hallengren.com*" -and $_.name -like "DatabaseBackup*" })

        #break;
    } # foreach Server
}
#$olajobs | Select Server, BackupType, Databases, Verify, Checksum, CleanupTime, Directory | Format-Table -AutoSize

#Output to a grid view in the ISE
$olajobs | Select Server, Enabled, JobName, BackupType, Databases, Verify, Checksum, CleanupTime, Directory, NumSchedules , SchdEnabled, Frequency, interval, LastRunOutcome | Out-GridView

#output to a CSV file
<#
$olajobs | 
    Select Server, Enabled, JobName, BackupType, Databases, Verify, Checksum, CleanupTime, Directory, NumSchedules , SchdEnabled, Frequency, interval | 
    export-csv "\\tog-sql\SOG\Apps\Microsoft\SQL Server\Backup Documentation\ASH-OLA $(get-date -Format "yyyy-MM-dd HHmmss") .csv"
#>