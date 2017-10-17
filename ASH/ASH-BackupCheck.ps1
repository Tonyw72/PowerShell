    function ASH-BackupCheck {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory=$true)][string[]] $BackupShares,
        [Switch]$NoProgress,        
        [switch]$ShowXLS,
        [switch]$IncludeLSN,
        [switch]$NoDiffCheck,
        [switch]$NoLogCheck,
        [switch]$IncludeSize,
        [Switch]$IncludeFileCounts,
        [string]$SavePath,
        [switch]$DontClose,
        [string]$TestServer
    )

    $StartTime = get-date
    $BackupStats = @()
    $i = 0

    cls

    foreach ($backupshare in $BackupShares) {        
        $j=0
        if(!$NoProgress) { Write-Progress -Activity "Processing $($backupshare)" -PercentComplete ($i/$BackupShares.Count*100) -Id 1}

        #$BackupShare
        $ServerNames =  @(Get-ChildItem $backupshare -Directory | Select-Object name)

        if ($ServerNames.Count -eq 0) {continue;}
                
        foreach ($Servername in $ServerNames) {            
            $k = 0                      
            
            if(!$NoProgress) { Write-Progress -Activity "Processing $($backupshare)\$($Servername.name)" -PercentComplete ($j/$ServerNames.Count*100) -Id 2 -ParentId 1}

            if($TestServer) {
                Write-Output "Connecting to $($TestServer)"
                $Server = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $TestServer
            }
            else {
                Write-Output "Connecting to $($Servername.name)"
                $Server = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $Servername.name.replace("$", "\") 
            }            
            
            $databases =  Get-ChildItem "$($backupshare)\$($Servername.name)" -Directory | Select-Object name
                
            foreach ($dbpath in $databases) {                
                $l=0
                if(!$NoProgress) { Write-Progress -Activity "Processing $($backupshare)\$($Servername.name)\$($dbpath.name)" -PercentComplete ($k/$databases.Count*100) -Id 3 -ParentId 2}
                #"`t$($dbpath.name)"
                $properties = @{
                    Server = "$($Servername.name)";
                    Database = "$($dbpath.name)";
                    RecoveryModel = "$(($server.databases | where {$_.name -eq "$($dbpath.name)"}).recoveryModel)";
                    BackupPath = "$($backupshare)";
                    FullCount = $null;                    
                    LastFull = $null;
                    LastFullLSN = $null;
                    DiffCount = $null;
                    LastDiff = $null;
                    LastDiffLSN = $null;
                    LastLog = $null;
                    LastLogLSN = $null;
                    LogCount = $null
                    }

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

                if ($fullFiles.count -eq 0) {
                    $BackupStats += New-Object psobject -Property $properties
                    continue;
                }

                if (Test-Path ($diffPath)) {$diffFiles = Get-ChildItem -Path $diffPath -file | ? { $_.LastWriteTime -gt (Get-Date).AddYears(-1)} | sort CreationTime -Descending  
                    }       
                    
                foreach ($fullfile in $fullFiles) {             
                                                    
                    #get a restore object         
                    try {   
                        Write-Verbose "Checking $($fullfile.fullname)"
                        $res = new-object("Microsoft.SqlServer.Management.Smo.Restore")
                        $res.Devices.AddDevice("$($fullfile.FullName)", [Microsoft.SqlServer.Management.Smo.DeviceType]::File)
                        $hdr = $res.ReadBackupHeader($Server) #| select databasename, FirstLSN, lastLSN | ft -AutoSize
                    }
                    Catch {
                        $err = $_.Exception
                        continue;
                    }

                    $CheckpointLSN = $hdr.CheckpointLSN
                    $lastLSn = $hdr.lastLSN
                    
                    $lastrestore = $fullfile.CreationTime  
                    $properties.FullCount = $fullFiles.count                  
                    $properties.LastFull = $fullfile.CreationTime                    
                    $properties.LastFullLSN = $hdr.lastLSN
                    $properties.DiffCount = $diffFiles.count
                    break;

                }

                # Check the diffs                
                foreach ($DiffFile in $diffFiles) {                                                          

                    $res = new-object("Microsoft.SqlServer.Management.Smo.Restore")
                    $res.Devices.AddDevice("$($DiffFile.FullName)", [Microsoft.SqlServer.Management.Smo.DeviceType]::File)
                    $hdr = $res.ReadBackupHeader($Server) #| select databasename, FirstLSN, lastLSN | ft -AutoSize

                    if ($CheckpointLSN -ne $hdr.DatabaseBackupLSN) {
                        Write-Verbose "Skipping $($DiffFile) it's not valid for this full backup"
                        continue;
                    }
                    $lastLSn = $hdr.LastLSN
                    $lastrestore = $DiffFile.CreationTime                    
                    $properties.LastDiff = $DiffFile.creationtime
                    $properties.LastDiffLSN = $hdr.LastLSN
                    break;
                }
                
                # get the logs
                if ((Test-Path($LogPath)) -and -not $NoLogCheck) {$logFiles = Get-ChildItem -Path $LogPath -file | ? { $_.LastWriteTime -gt ($lastrestore).addhours(-1)} | sort CreationTime 
                    }

                #check the logs     
                $LogLastLSN = $null  
                $properties.LogCount = $logfiles.count
                foreach ($logfile in $logfiles) {                             
                    $l++
                    if(!$NoProgress) { Write-Progress -Activity "Processing $($logfile.FullName)" -PercentComplete ($l/$logfiles.Count*100) -id 4 -ParentId 3}
                    $res = new-object("Microsoft.SqlServer.Management.Smo.Restore")
                    $res.Devices.AddDevice("$($logfile.FullName)", [Microsoft.SqlServer.Management.Smo.DeviceType]::File)
                    $hdr = $res.ReadBackupHeader($Server)
                        
                    if ($hdr.LastLSN -lt $LastLSN) {
                        #Write-Verbose "Skipped $($logfile) it's too old for this full backup (LastLSN: $($hdr.LastLSN))"
                        continue; 
                    }

                    if ($hdr.firstlsn -gt $LastLSN) {
                        Write-Error "Backup chain broken at $($logfile) (LastLSN: $($hdr.LastLSN))"
                        break ;
                    }

                    $lastLSN = $hdr.LastLSN

                    $properties.LastLog = $logfile.CreationTime
                    $properties.LastLogLSN = $hdr.LastLSN    
                      
                                      
                } # foreach ($logfile in $logfiles)
                
                $BackupStats += New-Object psobject -Property $properties
                
                $k++
                #break; #HACK
            } # foreach ($dbpath in $databases)                 

            $j++
        } # foreach ($Servername in $ServerNames)
            
        $i++
    }  # foreach ($backupshare in $BackupShares)

    #$BackupStats | Select Server, Database, BackupPath, LastFull, LastFullLSN, LastDiff, LastLog, LastLogLSN | ft * -AutoSize

     # Create a .com object for Excel
    $xl = new-object -comobject excel.application
    $xl.Visible = $ShowXLS # Set this to False when you run in production

    $wb = $xl.Workbooks.Add() # Add a workbook
    $ws = $wb.Worksheets.Item(1) # Add a worksheet 
    $cells=$ws.Cells
    $Row = 2
    $Col = 1    
    $Title = 'Results of Script to show ASH Backup Status as of:' 

    $cells.item($Row,$Col)="Server"
    $cells.item($Row,$Col).font.size=16; $col++
    $cells.item($Row,$Col)="Database"
    $cells.item($Row,$Col).font.size=16; $col++
    $cells.item($Row,$Col)="Recovery Model"
    $cells.item($Row,$Col).font.size=16; $col++
    $cells.item($Row,$Col)="Backup Path"
    $cells.item($Row,$Col).font.size=16; $col++
    $cells.item($Row,$Col)="Restore Date"
    $cells.item($Row,$Col).font.size=16; $col++
    $cells.item($Row,$Col)="Last Full"
    $cells.item($Row,$Col).font.size=16; $col++ 
    $cells.item($Row,$Col)="Last Diff"
    $cells.item($Row,$Col).font.size=16; $col++    
    $cells.item($Row,$Col)="Last Log"
    $cells.item($Row,$Col).font.size=16; $col++

    if ($includeFileCounts) {
        $cells.item($Row,$Col)="Full Count"
        $cells.item($Row,$Col).font.size=16; $col++  
        $cells.item($Row,$Col)="Diff Count"
        $cells.item($Row,$Col).font.size=16; $col++  
        $cells.item($Row,$Col)="Log Count"
        $cells.item($Row,$Col).font.size=16; $col++  
    }
    
    if ($IncludeLSN) {
        $cells.item($Row,$Col)="Last Full LSN"; $cells.item($Row,$Col).font.size=16; $col++
        $cells.item($Row,$Col)="Last Diff LSN"; $cells.item($Row,$Col).font.size=16; $col++
        $cells.item($Row,$Col)="Last Log LSN"; $cells.item($Row,$Col).font.size=16; $col++
    }

    $BadColor = 13551615 #Light Red
    $BadText = -16383844 #Dark Red


    foreach ($stat in $BackupStats) {
        $Col = 1
		$Row++
        $cells.item($row,$col)=$stat.Server; $col ++
        $cells.item($row,$col)=$stat.Database; $col++
        $cells.item($row,$col)=$stat.RecoveryModel; $col++
        $cells.item($row,$col)=$stat.BackupPath; $col++
        $cells.item($row,$col).formula = "=MAX(F$($row):H$($row))"; 
        $cells.item($row,$col).NumberFormat ='mm/dd/yyyy hh:mm'
        $col++
        $cells.item($row,$col)=$stat.LastFull; $col++        
        $cells.item($row,$col)=$stat.LastDiff; $col++        
        $cells.item($row,$col)=$stat.LastLog; $col++
        if ($includeFileCounts) {
            $cells.item($row,$col)=$stat.fullCount; $col++        
            $cells.item($row,$col)=$stat.DiffCount; $col++        
            $cells.item($row,$col)=$stat.LogCount; $col++        
        }
        if ($IncludeLSN) {
            $cells.item($row,$col)="'$($stat.LastFullLSN)"; $col++
            $cells.item($row,$col)="'$($stat.LastDiffLSN)"; $col++
            $cells.item($row,$col)="'$($stat.LastLogLSN)"; $col++
        }

    }

    $ws.UsedRange.AutoFilter() > $null
    $ws.UsedRange.EntireColumn.AutoFit() > $null

    $ws.application.activewindow.splitcolumn = 1
    $ws.application.activewindow.splitrow = 2
    $ws.application.activewindow.freezepanes = $true

    $cells.item(1,1)=$Title 
    $cells.item(1,1).font.size=24
    $cells.item(1,1).font.bold=$True
    $cells.item(1,1).font.underline=$True

    $sel = $ws.range("F1:H1")
    $sel.select() > $null
    $sel.MergeCells = $true

    $cells.item(1,6)=Get-Date
    $cells.item(1,6).NumberFormat ='mm/dd/yyyy h:mm'
    $cells.item(1,6).font.size=24
    $cells.item(1,6).font.bold=$True
    $cells.item(1,6).font.underline=$True

    #conditional formatting for the last backup date
    $sel = $ws.Range("E:E")
    $sel.FormatConditions.Delete() | Out-Null

    $formula1 = "=isblank(E1)"
    $Sel.FormatConditions.Add(2,0, $Formula1) | Out-Null
    #$sel.FormatConditions.StopIfTrue = "True"

    $Formula1 = '=E1 <= $F$1 - 2/24'
    $Sel.FormatConditions.Add(2,0, $Formula1) | Out-Null
    $sel.FormatConditions.Item(2).Interior.Color = $BadColor
    $sel.FormatConditions.Item(2).Font.Color = $BadText
    #$sel.FormatConditions.StopIfTrue = "True"

    $ws.range("A1").select() > $null
    
    #$savepath = "\\tog-sql\SOG\Apps\Microsoft\SQL Server\Backup Documentation"

    if ($SavePath -ne "") {    
        $wb.Saveas("$($savePath)")   
        if (-not $dontclose) {
            $xl.quit() 
        }
    }

    $EndTime = get-date
    $RunTime = New-TimeSpan -Start $StartTime -End $EndTime
    Write-Output "Process started at: $($StartTime)"
    Write-Output "Process ended   at: $($EndTime)"
    Write-Output "Run Duration: $("{0:hh}:{0:mm}:{0:ss}" -f $RunTime)"
}

$BackupPaths = @("\\in1-vnas01\btod01", "\\in1-vnas01\btod02", "\\in1-vnas01\btod03", "\\in1-vnas01\btod04", `
    "\\sd-vnas01\btod01", "\\sd-vnas01\btod02", "\\sd-vnas01\btod03", "\\sd-vnas01\btod04", `
    "\\sd-vnas02\btod01", "\\sd-vnas02\btod02", "\\sd-vnas02\btod03", "\\sd-vnas02\btod04")

#ASH-BackupCheck -BackupShare "\\in1-vnas01\btod01" -IncludeFileCounts -Verbose -ShowXLS #-NoLogCheck 

<#
ASH-BackupCheck -BackupShare "\\in1-vnas01\btod04" -IncludeFileCounts -Verbose -ShowXLS -NoLogCheck # -NoLogCheck # -NoProgress
ASH-BackupCheck -BackupShares @("\\in1-vnas01\btod01","\\in1-vnas01\btod02", "\\in1-vnas01\btod03", "\\in1-vnas01\btod04")  -Verbose -ShowXLS -IncludeFileCounts #-NoLogCheck # -NoProgress
ASH-BackupCheck -BackupShares @("\\sd-vnas01\btod01","\\sd-vnas01\btod02", "\\sd-vnas01\btod03", "\\sd-vnas01\btod04")  -Verbose -ShowXLS -IncludeFileCounts #-NoLogCheck # -NoProgress
ASH-BackupCheck -BackupShares @("\\sd-vnas02\btod01","\\sd-vnas02\btod02", "\\sd-vnas02\btod03", "\\sd-vnas02\btod04")  -Verbose -ShowXLS -IncludeFileCounts #-NoLogCheck # -NoProgress

#ASH-BackupCheck -BackupShares $BackupPaths -Verbose -ShowXLS -NoLogCheck -NoDiffCheck

ASH-BackupCheck -BackupShare "\\sd-vnas02\btod01" -IncludeFileCounts -Verbose -ShowXLS -NoLogCheck ` # -NoLogCheck # -NoProgress
    -savepath: "\\tog-sql\SOG\Apps\Microsoft\SQL Server\Backup Documentation\ASH Backup Status $(get-date -Format "yyyy-MM-dd HHmmss").xlsx"

#>
<#

ASH-BackupCheck -BackupShares @("\\in1-vnas01\btod01","\\in1-vnas01\btod02", "\\in1-vnas01\btod03", "\\in1-vnas01\btod04")  -Verbose -ShowXLS -IncludeFileCounts `
    -savepath: "\\tog-sql\SOG\Apps\Microsoft\SQL Server\Backup Documentation\ASH Backup Status IN1-vnas01 $(get-date -Format "yyyy-MM-dd HHmmss").xlsx"

ASH-BackupCheck -BackupShares @("\\sd-vnas02\btod01","\\sd-vnas02\btod02", "\\sd-vnas02\btod03", "\\sd-vnas02\btod04")  -Verbose -ShowXLS -IncludeFileCounts `
    -savepath: "\\tog-sql\SOG\Apps\Microsoft\SQL Server\Backup Documentation\ASH Backup Status sd-vnas02 $(get-date -Format "yyyy-MM-dd HHmmss").xlsx"

ASH-BackupCheck -BackupShares @("\\sd-vnas01\btod01","\\sd-vnas01\btod02", "\\sd-vnas01\btod03", "\\sd-vnas01\btod04")  -Verbose -ShowXLS -IncludeFileCounts `
    -savepath: "\\tog-sql\SOG\Apps\Microsoft\SQL Server\Backup Documentation\ASH Backup Status sd-vnas01 $(get-date -Format "yyyy-MM-dd HHmmss").xlsx"

#>