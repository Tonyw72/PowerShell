function Install-OlaBackupSolution
{
[CmdletBinding(DefaultParameterSetName="Default", SupportsShouldProcess = $true)] 


Param(
	[parameter(Mandatory = $true, ValueFromPipeline = $true)]
	[string]$SqlServer,
    [string]$BackupDir,
    [int]$CleanupTime,
    [string]$Schedule,
    [string]$Alerts,
    [switch]$StartSystem,
    [switch]$StartFull
	)

    BEGIN
    {
        Write-Verbose "Start Loop"

        #[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | out-null
        #[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") | out-null

        #function PSScriptRoot { $MyInvocation.ScriptName | Split-Path }

        #$MaintenanceSolution = "$(PSScriptRoot)\scripts\MaintenanceSolution.sql"
        $MaintenanceSolution = "\\SD-TOG\SOG\Apps\Microsoft\SQL Server\Scripts\Post Install Scripts\001_MaintenanceSolution.sql"

        $script = @()
        [string]$scriptpart 

        $fullscript = Get-Content $MaintenanceSolution
        foreach($line in $fullscript)
        {   
            if ($line -ne "GO")
            {
                if ($BackupDir -and $line -match "Specify the backup root directory")
                {
                    $line = $line.Replace("E:\sqlbackups", $BackupDir)
                    #$line
                }
                if ($CleanupTime -and $line -match "Time in hours, after which backup files are deleted")
                {
                    $line = $line.Replace("24", $CleanupTime)
                    #$line
                }      

                $scriptpart += $line + "`n"
            }
            else
            {
                $properties = @{Scriptpart = $scriptpart}
                $newscript = New-Object PSObject -Property $properties
                $script += $newscript
                $scriptpart = ""
                $newscrpt = $null
            }
        }
    }

    PROCESS
    {
        $out = "Installing Maintenance solution on server: {0}" -f $SqlServer
        Write-Verbose $out

        $ConnectionString = "Server = $SqlServer ; Database = master; Integrated Security = True;"
        $Connection = New-Object System.Data.SQLClient.SQLConnection 
        $Connection.ConnectionString = $ConnectionString      
        $Connection.Open();

        $Command = New-Object System.Data.SQLClient.SQLCommand 
        $Command.Connection = $Connection

        if($PSCmdlet.ShouldProcess("$($SqlServer)","Adding OLA maintenance jobs")){
            foreach ($scriptpart in $script)
            {
                if ($scriptpart.scriptpart) {   
                    $Command.CommandText = $($scriptpart.scriptpart)
                    $niks = $Command.ExecuteNonQuery()
                }
            }
        }

        if($PSCmdlet.ShouldProcess("$($SqlServer)","Scheduling OLA maintenance jobs")){
            if ($Schedule)
            {
                $Command.CommandText = get-content $Schedule
                $niks = $Command.ExecuteNonQuery();
            }
        }

        if($PSCmdlet.ShouldProcess("$($SqlServer)","Adding OLA maintenance alert notifications")){
            if ($alerts)
            {
                $Command.CommandText = get-content $alerts
                $niks = $Command.ExecuteNonQuery();
            }
        }

        $server  = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $SqlServer        

        # Start the System DB Backup
        if($PSCmdlet.ShouldProcess("$($SqlServer)","Starting System Full backup job")){
            if ($StartSystem) {
                Write-Verbose "Starting System Full backup job"
                ($server.JobServer.Jobs["DatabaseBackup - SYSTEM_DATABASES - FULL"]).Start()
                Start-Sleep -Seconds 10
            }
        }
        
        # Start the User Backup
        if($PSCmdlet.ShouldProcess("$($SqlServer)","Starting User Full backup job")){
            if ($StartFull) {
                Write-Verbose "Starting User Database Full backup job"
                ($server.JobServer.Jobs["DatabaseBackup - USER_DATABASES - FULL"]).Start()
            }
        }

        $Connection.Close();            
    }

    END
    {
        Write-Verbose "End Loop"
    }

}