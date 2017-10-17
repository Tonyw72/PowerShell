

function ASH-CheckInvalidBackups {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory=$true)][string[]] $BackupShares
        )


    $StartTime = get-date
    $BackupStats = @()
    $i = 0

    cls

    foreach ($backupshare in $BackupShares) { 
        Write-Verbose "Processing $($backupshare)"

        # Get the list of directories
        $ServerNames =  @(Get-ChildItem $backupshare -Directory | Select-Object name)

        if ($ServerNames.Count -eq 0) {continue;}

        foreach ($Servername in $ServerNames) {  
            
            Write-Verbose "`tChecking $($Servername.name)"
        
            $Server = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $Servername.name 

            foreach ($dbpath in $server.databases) {

                $CheckpointLSN = $null
                $lastLSN = $null
            
                $fullPath = "$($backupshare)\$($Servername.name)\$($dbpath.name)\FULL\"
                $fullFiles = @()                

                $diffPath = "$($backupshare)\$($Servername.name)\$($dbpath.name)\DIFF\"
                $diffFiles = @()

                $LogPath = "$($backupshare)\$($Servername.name)\$($dbpath.name)\Log\"
                $LogFiles = @()

                #get the list of backups
                if (Test-Path($fullPath)) {
                   $fullFiles = Get-ChildItem -Path "$($backupshare)\$($Servername.name)\$($dbpath.name)\FULL\" -file | ? { $_.LastWriteTime -gt (Get-Date).AddYears(-1)} | sort CreationTime -Descending
                }
                else {
                    Write-Verbose "`t`t$($servername.name) - $($dbpath.name) - FULL - No FULL backups"
                    continue;
                }

                foreach ($fullfile in $fullFiles) { 

                    #get a restore object         
                    try {         
                        $res = new-object("Microsoft.SqlServer.Management.Smo.Restore")
                        $res.Devices.AddDevice("$($fullfile.FullName)", [Microsoft.SqlServer.Management.Smo.DeviceType]::File)
                        $hdr = $res.ReadBackupHeader($Server) #| select databasename, FirstLSN, lastLSN | ft -AutoSize

                        $age = (New-TimeSpan -Start $fullfile.CreationTime).TotalHours
                        
                    
                        Write-Output "`t`t$($servername.name) - $($dbpath.name) - FULL - $($fullfile.CreationTime)"

                    }
                    Catch {
                        $err = $_.Exception
                        continue;
                    }

                    $CheckpointLSN = $hdr.CheckpointLSN
                    $lastLSN = $hdr.lastLSN

                    break;

                } # foreach ($fullfile in $fullFiles)

                if ($lastLSN -eq $null) {
                    Write-Output "`t`t$($servername.name) - $($dbpath.name) - FULL - NO Valid backups"
                    continue;
                }

                if (Test-Path ($diffPath)) {
                    $diffFiles = Get-ChildItem -Path $diffPath -file | ? { $_.LastWriteTime -gt (Get-Date).AddYears(-1)} | sort CreationTime -Descending
                } 

                foreach ($diffFile in $diffFiles) {
                    $res = new-object("Microsoft.SqlServer.Management.Smo.Restore")
                    $res.Devices.AddDevice("$($DiffFile.FullName)", [Microsoft.SqlServer.Management.Smo.DeviceType]::File)
                    $hdr = $res.ReadBackupHeader($Server) #| select databasename, FirstLSN, lastLSN | ft -AutoSize




                } # foreach ($diffFile in $diffFiles)


            } # foreach ($dbpath in $server.databases)

        } # foreach ($Servername in $ServerNames)


    } # foreach ($backupshare in $BackupShares)


    
    $EndTime = get-date
    $RunTime = New-TimeSpan -Start $StartTime -End $EndTime
    Write-Output "Process started at: $($StartTime)"
    Write-Output "Process ended   at: $($EndTime)"
    Write-Output "Run Duration: $("{0:hh}:{0:mm}:{0:ss}" -f $RunTime)"
}

ASH-CheckInvalidBackups -BackupShares @("\\sd-vnas02\btod01") -Verbose