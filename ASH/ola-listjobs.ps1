function Get-BackupFolderSize {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [ValidateSet(“Full”,”Diff”,”Log”)]
        [string]$Type
    )

    $size = 0

    foreach ($folder in (Get-ChildItem $Path -Directory -Recurse)) {
        if ($folder.Name -eq $Type) {
            $size += (Get-ChildItem $Folder.FullName -Recurse | Measure-Object Length -Sum).Sum /1MB
        }
    }

    $size
}

Function Ola-ListJobs {
    [cmdletbinding()]
    param ( 
        [String] $CMSServerName = "TOG-SQL",
        #[String[]] $ServerGroups,
        [String[]] $ServerList,
        [switch]$ToGrid,
        [switch]$ToTable,
        [string] $OutputPath = ""      
    )    
    #. "\\tog-sql\SOG\Apps\Microsoft\SQL Server\Powershell\Scripts\get-serverlist.ps1"
    <#
    Write-Verbose "Listing Ola Backup Jobs & Parameters"
    Write-Verbose "CMS Name: $($CMSServerName)"
    if ($ServerGroups.Count -gt 0) {
        Write-Verbose "CMS Groups: "
        $ServerGroups | foreach -Process {write-verbose "`t $($_)"}
    }
    if ($ServerList.Count -gt 0) {
        Write-Verbose "Specified Servers: "
        $ServerList | foreach -Process {Write-Verbose "`t $($_)"}
    }
    Write-Verbose "Output to Table: $($ToTable)"
    Write-Verbose "Output to Grid: $($ToGrid)"    
    Write-Verbose "Output path: $($OutputPath)"

    $StartTime = get-date

    $connectionString = "data source=$CMSServerName;initial catalog=master;integrated security=sspi;" 
    $sqlConnection = New-Object ("System.Data.SqlClient.SqlConnection") $connectionstring 
    $conn = New-Object ("Microsoft.SQLServer.Management.common.serverconnection") $sqlconnection 
    $cmsStore = New-Object ("Microsoft.SqlServer.Management.RegisteredServers.RegisteredServersStore") $conn 
    $cmsRootGroup = $cmsStore.ServerGroups["DatabaseEngineServerGroup"].ServerGroups       
    
    # Get the servers from the CMS Groups
    foreach ($group in $ServerGroups) {        
        Get-ServerList -cmsName $CMSServerName -serverGroup $group -recurse | foreach -process { $ServerList += $_.servername}
    }
    #>

    $StartTime = get-date

    # no serverlist or group passed in, so process the whole CMS
    if ($ServerList.Count -eq 0) {
        #$cmsRootGroup.RegisteredServers | Sort-Object -property servername -unique | foreach -process { $ServerList += $_.servername}    
        #Get-ServerList -cmsName $CMSServerName -recurse | foreach -process { $ServerList += $_.servername} 
        $ServerList += Get-DbaRegisteredServerName -SqlServer "$CMSServerName" | 
            Select -Expandproperty Name |
            Where-Object {$_ -ne "10.8.6.38"} |
            Sort-Object -Unique
    }

    if ($ServerList.Count -eq 0) {
        Write-Output "No servers to process"
        break;
    }

    #$ServerList | Format-Table -AutoSize
    $serverlist = $serverlist | Sort-Object -unique

    # reset variables
    $i=0
    $olajobs = @()

    # Loop though the list of server names
    foreach ($ServerName in $serverlist | Sort-Object -unique) {
        Write-Progress -Activity "Processing $($ServerName)" -PercentComplete ($i/$serverlist.Count*100)
        Write-Verbose "Processing $($ServerName)"
       
        # Connect to the SQL server
        $server  = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $ServerName
        
        Write-Verbose "`t # of SQL AgentJobs $($server.JobServer.Jobs.count)"
        Write-Progress -Activity "Processing $($ServerName) - Searching through the jobs ($($server.JobServer.Jobs.count))" -PercentComplete ($i/$serverlist.Count*100)

        # Get the list of Ola backup jobs
        $jobs = $server.JobServer.Jobs | where {$_.Description -like "*ola.hallengren.com*" -and $_.name -like "DatabaseBackup*"} 

        if ($server.Version.Major -gt 10 -or ($server.Version.Major -eq 10 -and $server.Version.Minor -eq 50)) {
            $Compressed = $server.Configuration.DefaultBackupCompression.ConfigValue
        }
        else {
            $Compressed = "N/A"
        }

        # get the SQL Service account
        #$SMOWmiserver = New-Object ('Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer') $Servername
        #$ChangeService = $SMOWmiserver.Services | where {$_.name -eq "MSSQLSERVER"}
        $svc = Get-WmiObject -Class Win32_Service -ComputerName $Servername.split("\")[0] -Filter 'Name = "MSSQLSERVER"' -ErrorAction SilentlyContinue     
        $ServiceAcct = $svc.startname

        # No Ola Backup Jobs on this server
        if ($jobs.count -eq 0) {
            $properties = @{
                Server = $server.Name;
                ServiceAccount = $ServiceAcct;
                Compressed = $Compressed;
                Jobname = "";
                Enabled = $false;
                Databases = "";
                Directory = "";
                BackupType = "";
                Size = $null;
                Notification = $null
                Verify = "";
                Checksum = "";
                LogToTable = "";
                CleanupTime = $null;  
                NumSchedules =  "";                 
                SchdEnabled = "";
                Frequency = "";
                Interval = "";
                LastRunOutcome = ""
                }
            $ola = New-Object psobject -Property $properties
            $olajobs += $ola
            continue
        }

        # Loop through the jobs
        foreach ($job in $server.JobServer.Jobs | where {$_.Description -like "*ola.hallengren.com*" -and $_.name -like "DatabaseBackup*"}) {    
        
            Write-Output "$($Server.name) - $($job.Name): $($job.LastRunOutcome)"   
            
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
                                
                if (Test-Path("$($directory)\$($server.Name)")) {
                    Write-Progress -Activity "Processing $($ServerName) - Getting the foldersize for $($backuptype)" -PercentComplete ($i/$serverlist.Count*100) 
                    #$size = Get-BackupFolderSize -Path "$($directory)\$($server.Name)" -Type $backuptype
                }

                if($job.JobSchedules.Count -eq 0) {
                    $properties = @{
                        Server = $server.Name;
                        ServiceAccount = $ServiceAcct;
                        Compressed = $Compressed;
                        Jobname = $job.Name;
                        Enabled = $Job.IsEnabled;
                        Databases = $databases;
                        Directory = $directory;
                        BackupType = $backuptype;
                        Size = $size;
                        Notification = $job.EmailLevel;
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
                else {
                    foreach ($schd in $job.JobSchedules | where {$_.isenabled -eq $true}) {
                        $properties = @{
                            Server = $server.Name;
                            ServiceAccount = $ServiceAcct;
                            Compressed = $Compressed;
                            Jobname = $job.Name;
                            Enabled = $Job.IsEnabled;
                            Databases = $databases;
                            Directory = $directory;
                            BackupType = $backuptype;
                            Size = $size;
                            Notification = $job.EmailLevel;
                            Verify = $verify;
                            Checksum = $checksum;
                            LogToTable = $logtotable;
                            CleanupTime = $CleanupTime;  
                            NumSchedules =  $job.JobSchedules.Count;                 
                            SchdEnabled = $schd.isenabled.tostring();
                            Frequency = $schd.FrequencyTypes.tostring();
                            Interval = ""
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
                }

            } # foreach ($step in $job.JobSteps | where {$_.SubSystem -eq "CmdExec"})            

        } # foreach ($job in $server.JobServer.Jobs | where {$_.Description -like "*ola.hallengren.com*" -and $_.name -like "DatabaseBackup*" })

        $i += 1
    }

    Write-Progress -Activity "done" -Completed


    if ($ToTable -eq $true) {
        $olajobs | Select Server, Enabled, BackupType, CleanUpTime, SchdEnabled, Frequency, interval, Directory | Format-Table -AutoSize
    }

    if ($ToGrid -eq $true) {
        $olajobs | 
            Select Server, ServiceAccount, Compressed, Enabled, Notification, JobName, BackupType, Databases, Verify, Checksum, CleanupTime, Directory, NumSchedules , SchdEnabled, Frequency, interval, LastRunOutcome | 
            Out-GridView
    }

    if ($OutputFile -ne "") {
        $olajobs | 
            Select Server, ServiceAccount, Compressed, Enabled, JobName, Notification, BackupType, Databases, Verify, Checksum, CleanupTime, Directory, NumSchedules , SchdEnabled, Frequency, interval, LastRunOutcome | 
            export-csv "$($OutputPath)\ASH-OLA $(get-date -Format "yyyy-MM-dd HHmmss").csv"
    }

    $EndTime = get-date
    $RunTime = New-TimeSpan -Start $StartTime -End $EndTime
    Write-Output "Process started at: $($StartTime)"
    Write-Output "Process ended   at: $($EndTime)"
    Write-Output "Run Duration: $("{0:hh}:{0:mm}:{0:ss}" -f $RunTime)"
}

#Ola-ListJobs -ServerGroups @("Prod 2008 DR", "Prod 2008") -verbose -ToGrid #-ServerList @("ACNSQL")

<#
Ola-ListJobs -togrid -verbose -OutputPath "\\tog-sql\SOG\Apps\Microsoft\SQL Server\Backup Documentation" #-ServerGroups "Prod 2008 DR"
#>    
    <#`
    -ServerGroups "Prod 2008 DR" `
    -ServerList "ACNSQL" `
    -Verbose
    #>
#Ola-ListJobs -ToGrid -OutputPath "\\tog-sql\SOG\Apps\Microsoft\SQL Server\Backup Documentation"

#Ola-ListJobs -ServerList @("in1-edi", "IN1-CRMSTGSQL") -ToGrid