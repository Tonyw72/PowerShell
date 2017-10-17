Function RestoreFullBackups {
    [cmdletbinding(SupportsShouldProcess=$True)]
    param ( 
       [Parameter(Mandatory=$true)][ref]$Server,
       [Parameter(Mandatory=$true)][string]$dbname,
       [Parameter(Mandatory=$true)][string]$path,
       [Parameter(Mandatory=$true)][ref]$CheckpointLSN,
       [Parameter(Mandatory=$true)][ref]$LastLSN
    )
    "Restoring full backup for: $($dbname) on $($Server.value.name)"
    [switch]$restoredFull = $false

    $fullFiles = Get-ChildItem -Path "$($path)\$($dbname)\FULL\" -file | ? { $_.LastWriteTime -gt (Get-Date).AddYears(-1)} | sort CreationTime -Descending
    foreach ($file in $fullFiles) {       
        
        if($restoredFull -eq $True) {break;}

        $res = new-object("Microsoft.SqlServer.Management.Smo.Restore")

        $res.Devices.AddDevice("$($path)\$($dbname)\FULL\$($file)", [Microsoft.SqlServer.Management.Smo.DeviceType]::File)
                    
        $hdr = $res.ReadBackupHeader($Server.Value) #| select databasename, FirstLSN, lastLSn | ft -AutoSize
        $LastLSN.Value = $hdr.LastLSN
        $CheckpointLSN.Value = $hdr.CheckpointLSN
        #write-verbose $LastRestoredLSN 

        # Relocate the data & log files to the server defaults
        foreach ($f in $res.ReadFileList($Server.Value)) {
            $rf = new-object -typename Microsoft.SqlServer.Management.Smo.RelocateFile
            $rf.LogicalFileName = $f.logicalname
            #$rf.PhysicalFileName = 
                        
            # Log file
            if ($f.type -eq 'L') {
                $rf.PhysicalFileName = "$($Server.Value.settings.DefaultLog)\$(Split-Path $f.PhysicalName -Leaf)"
            }
            # data file 
            elseif ($f.type -eq 'D') {
                $rf.PhysicalFileName = "$($Server.Value.settings.DefaultFile)\$(Split-Path $f.PhysicalName -Leaf)"
            }
            else {
                "Error"
                break;
            }                        
            $res.RelocateFiles.Add($rf) > $null
        }

        try {
            "Restoring $($dbname) on $($srvname.servername)"
            if($PSCmdlet.ShouldProcess($srvname.servername,"Restoring FULL: $($file) (Last LSN: $($hdr.lastlsn))")) {
                #restore the database    
                Write-Verbose "Restoring $($file)"                        
                $res.Action = [Microsoft.SqlServer.Management.Smo.RestoreActionType]::Database
                $res.NoRecovery = $true
                $res.database = $dbname
                $res.ReplaceDatabase = $True
                $res.sqlrestore($Server.Value)                                
            } # whatif
        }# Try
        catch {                           
            # Handle the error
            $err = $_.Exception
            write-output $err.Message
            while( $err.InnerException ) {
                    $err = $err.InnerException
                    write-output $err.Message
                }
        } #Catch                        
        finally {
            $restoredFull = $True
        } #finally

    } # foreach ($file in $fullFiles) 
}

Function RestoreDIFFBackups {
    [cmdletbinding(SupportsShouldProcess=$True)]
    param ( 
       [Parameter(Mandatory=$true)][ref]$Server,
       [Parameter(Mandatory=$true)][string]$dbname,
       [Parameter(Mandatory=$true)][string]$path,
       [Parameter(Mandatory=$true)][ref]$CheckpointLSN,
       [Parameter(Mandatory=$true)][ref]$LastLSN
    )
    "Restoring diff backup for: $($dbname) on $($Server.value.name)"

    [switch]$diffRestored = $false
    $diffFiles = Get-ChildItem -Path "$($path)\$($dbname)\DIFF\" -file | ? { $_.LastWriteTime -gt (Get-Date).AddYears(-1)} | sort CreationTime -Descending  

    foreach ($file in $diffFiles) {  
        if ($diffRestored -eq $True) { break }
        try {
            $res = new-object("Microsoft.SqlServer.Management.Smo.Restore")                                        
            $res.Devices.AddDevice("$($path)\$($dbname)\DIFF\$($file)", [Microsoft.SqlServer.Management.Smo.DeviceType]::File)                       
                    
            $hdr = $res.ReadBackupHeader($Server.value) 
            <#
            "File: $($file)"                        
            "     Last LSN: $($LastLSN)"
            "TXN  Last LSN: $($hdr.lastlsn)"
            "$($hdr.lastlsn -gt $LastLSN)"

            "TXN First LSN: $($hdr.firstlsn)"
            "     Last LSN: $($LastLSN)"                        
            "$($hdr.firstlsn -le $LastLSN)"                                                
            #>

            #$file.Name
            #$hdr | select databasename, FirstLSN, lastLSn, DatabaseBackupLSN, DifferentialBaseLSN, CheckpointLSN   | ft -AutoSize
            #$hdr | gm

            if ($CheckpointLSN.Value -ne $hdr.DatabaseBackupLSN) {
                Write-Verbose "Skipping $($file) it's not valid for this full backup"
                continue;
            }                        
                        
                    
            #"Restoring differential for $($dir.name) on $($srvname.servername)"
            if($PSCmdlet.ShouldProcess($Server.Value.name,"Restoring DIFF: $($file) (Last LSN: $($hdr.lastlsn))")) {
                Write-Verbose "Restoring $($file)"
                $res.Action = [Microsoft.SqlServer.Management.Smo.RestoreActionType]::Database
                $res.NoRecovery = $true
                $res.database = $dbname
                $res.sqlrestore($Server.value)                                                                               
            }                        
            $LastLSN.value = $hdr.lastlsn 
            $diffRestored = $True
                        
        } # Try
        catch {                           
            # Handle the error
            $err = $_.Exception
            write-output $err.Message
            while( $err.InnerException ) {
                    $err = $err.InnerException
                    write-output $err.Message
                }                        
        } #Catch   

    } # foreach ($file in $diffFiles)
                
}

function RestoreLOGBackups {
    [cmdletbinding(SupportsShouldProcess=$True)]
    param ( 
       [Parameter(Mandatory=$true)][ref]$Server,
       [Parameter(Mandatory=$true)][string]$dbname,
       [Parameter(Mandatory=$true)][string]$path,
       #[Parameter(Mandatory=$true)][ref]$CheckpointLSN,
       [Parameter(Mandatory=$true)][ref]$LastLSN,
       [switch]$ShowSkipped = $false

    )    
    #"Restoring log files for $($dbname) on $($Server.value.name)"

    $logFiles = Get-ChildItem -Path "$($livebackuppath)\$($dir.name)\LOG\" -file | ? { $_.LastWriteTime -gt (Get-Date).AddYears(-1)} | sort CreationTime 
    if ($logFiles.count -gt 0) {                
        "Restoring log files for $($dbname) on $($Server.value.name)"
    }
    else{
        "No log files to restore"
        break
    }

    foreach ($file in $logFiles) {         
        try {
            $res = new-object("Microsoft.SqlServer.Management.Smo.Restore")                                        
            $res.Devices.AddDevice("$($path)\$($dbname)\LOG\$($file)", [Microsoft.SqlServer.Management.Smo.DeviceType]::File)                       
                    
            $hdr = $res.ReadBackupHeader($Server.Value)

            if ($hdr.LastLSN -le $LastLSN.value) {  
                if ($ShowSkipped -eq $True) {                      
                    Write-Verbose "Skipped $($file) it's too old for this full backup (LastLSN: $($hdr.LastLSN))"
                }
                $skipped += 1
                continue;
            }
                        
            #$x += 1

            Write-Debug "File: $($file)"                        
            Write-Debug "     Last LSN: $($LastLSN.Value)"
            Write-Debug "TXN  Last LSN: $($hdr.lastlsn)"
            Write-Debug "$($hdr.lastlsn -gt $LastLSN.Value)"

            Write-Debug "TXN First LSN: $($hdr.firstlsn)"
            Write-Debug "     Last LSN: $($LastLSN.Value)"                        
            Write-Debug "$($hdr.firstlsn -le $LastLSN.Value)" 

            #if ($x -ge 5) {break;}

            if ($hdr.firstlsn -gt $LastLSN.value){
                Write-Verbose "Skipping $($file) it's not valid for this backup chain (LastLSN: $($hdr.LastLSN))"
                continue;
            }                        

            if($PSCmdlet.ShouldProcess($Server.Value.name,"Restoring  LOG: $($file)")) {
                Write-Verbose "Restoring $($file)"
                $res.Action = [Microsoft.SqlServer.Management.Smo.RestoreActionType]::Log
                $res.NoRecovery = $true
                $res.database = $dir.name
                $test = $res.sqlrestore($Server.Value)                                                        
                #$test
            }
            $LastLSN.value = $hdr.lastlsn
                    
            } # Try
            catch {                           
                # Handle the error
                $err = $_.Exception
                write-output $err.Message
                while( $err.InnerException ) {
                        $err = $err.InnerException
                        write-output $err.Message
                    }                        
            } #Catch   
        } # foreach ($file in $logFiles) 
}

function ASHDRRestore {
[cmdletbinding(SupportsShouldProcess=$True)]
param (
    [string]$RestoreServer,
    [String]$RestoreDataBase,
    [switch]$ShowSkipped = $false
         )
    # Connect to the CMS and get a list of the Production 2008 DR servers
    $serverList = Get-ServerList -cmsName 'tog-sql'  -serverGroup "Prod 2008 DR" -recurse 
    #$serverList | Format-Table
    
    # Loop through the DR servers on the CMS
    foreach ($srvname in $serverList) {    
    
        # Check to make sure that we're restoring a single or all DR servers
        if ($RestoreServer -ne "" -and $srvname.servername -ne $RestoreServer) {
            Write-Debug "Skipping server: $($srvname.servername)"
            #Write-Verbose "Skipping server: $($srvname.servername)"
            continue
        }    

        # connect to the DR server
        $srv = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $srvname.servername   
        $main = $srvname.servername.Split("{-}")[0]             
                
        #get the default backup directory
        $backupdrive = $srv.BackupDirectory[0]        
        $livebackuppath = "\\$($srvname.servername)\$($backupdrive)`$\sqldbbackups\$main\"

        "Restoring databases on: $($srvname.servername) from $($main)"
        "From: $($livebackuppath) - $(Test-Path $livebackuppath)"
        Write-Verbose "Default data directory: $($srv.Settings.DefaultFile )"
        Write-Verbose "Default log directory: $($srv.Settings.DefaultLog)"

        if (Test-Path $livebackuppath) {
            #get the sub directory
            $dirs = Get-ChildItem -Path $livebackuppath -Directory
            
            #loop through all the database backup folders
            foreach ($dir in $dirs){
                #$dir.name
                $diffLSN = ""

                #check to make sure we're restoring the correct database
                if ($RestoreDataBase -ne "" -and $RestoreDataBase -ne $dir.name) {
                    Write-Debug "Skipping database: $($dir.name)"
                    #Write-Verbose "Skipping database: $($dir.name)"
                    continue
                }

                [switch]$restoredFull = $false
                $LastRestoredLSN = ""
                $CheckpointLSN = ""
                
                #Restore the full backups
                if (test-path "$($livebackuppath)\$($dir.name)\FULL\"){
                    RestoreFullBackups -Server ([ref]$srv) `
                        -dbname $dir.name `
                        -path $livebackuppath `
                        -LastLSN ([ref]$LastRestoredLSN) `
                        -CheckpointLSN ([ref]$CheckpointLSN)
                }
<#                
                # Get the list of full backup files
                $fullFiles = Get-ChildItem -Path "$($livebackuppath)\$($dir.name)\FULL\" -file | ? { $_.LastWriteTime -gt (Get-Date).AddYears(-1)} | sort CreationTime -Descending
                foreach ($file in $fullFiles) {
                    if ($restoredFull){break}
                        
                        $res = new-object("Microsoft.SqlServer.Management.Smo.Restore")
                                        
                        $res.Devices.AddDevice("$($livebackuppath)\$($dir.name)\FULL\$($file)", [Microsoft.SqlServer.Management.Smo.DeviceType]::File)
                    
                        $hdr = $res.ReadBackupHeader($srv) #| select databasename, FirstLSN, lastLSn | ft -AutoSize
                        $LastRestoredLSN = $hdr.LastLSN
                        $CheckpointLSN = $hdr.CheckpointLSN
                        write-verbose $LastRestoredLSN 
                                             
                    
                        # Relocate the data & log files to the server defaults
                        foreach ($f in $res.ReadFileList($srv)) {
                            $rf = new-object -typename Microsoft.SqlServer.Management.Smo.RelocateFile
                            $rf.LogicalFileName = $f.logicalname
                            #$rf.PhysicalFileName = 
                        
                            # Log file
                            if ($f.type -eq 'L') {
                                $rf.PhysicalFileName = "$($srv.Settings.DefaultLog)\$(Split-Path $f.PhysicalName -Leaf)"
                            }
                            # data file 
                            elseif ($f.type -eq 'D') {
                                $rf.PhysicalFileName = "$($srv.Settings.DefaultLog)\$(Split-Path $f.PhysicalName -Leaf)"
                            }
                            else {
                                "Error"
                                break;
                            }                        
                            $res.RelocateFiles.Add($rf) 
                        }
                    
                        try {
                            "Restoring $($dir.name) on $($srvname.servername)"
                            if($PSCmdlet.ShouldProcess($srvname.servername,"Restoring FULL: $($file)")) {
                                #restore the database                            
                                $res.Action = [Microsoft.SqlServer.Management.Smo.RestoreActionType]::Database
                                $res.NoRecovery = $true
                                $res.database = $dir.name
                                $res.ReplaceDatabase = $True
                                $res.sqlrestore($srv)                                
                            } # whatif
                        }# Try
                        catch {                           
                            # Handle the error
                            $err = $_.Exception
                            write-output $err.Message
                            while( $err.InnerException ) {
                                    $err = $err.InnerException
                                    write-output $err.Message
                                }
                        } #Catch                        
                        finally {
                            $restoredFull = $True
                        } #finally

                     #} # if ($restoredFull -eq $false)

                } # foreach ($file in $fullFiles)

                if ($restoredFull -ne $True) {continue;}
#>
                # Restore Diff if available
                if (test-path "$($livebackuppath)\$($dir.name)\DIFF\"){
                    RestoreDiffBackups -Server ([ref]$srv) `
                        -dbname $dir.name `
                        -path $livebackuppath `
                        -LastLSN ([ref]$LastRestoredLSN) `
                        -CheckpointLSN ([ref]$CheckpointLSN)

                }
<#
                $diffFiles = Get-ChildItem -Path "$($livebackuppath)\$($dir.name)\DIFF\" -file | ? { $_.LastWriteTime -gt (Get-Date).AddYears(-1)} | sort CreationTime -Descending  
                $diffRestored = $false              
                foreach ($file in $diffFiles) {  
                    if ($diffRestored -eq $True) { break }
                    try {
                        $res = new-object("Microsoft.SqlServer.Management.Smo.Restore")                                        
                        $res.Devices.AddDevice("$($livebackuppath)\$($dir.name)\DIFF\$($file)", [Microsoft.SqlServer.Management.Smo.DeviceType]::File)                       
                    
                        $hdr = $res.ReadBackupHeader($srv) 
                        
                        #"File: $($file)"                        
                        #"     Last LSN: $($LastRestoredLSN)"
                        #"TXN  Last LSN: $($hdr.lastlsn)"
                        #"$($hdr.lastlsn -gt $LastRestoredLSN)"

                        #"TXN First LSN: $($hdr.firstlsn)"
                        #"     Last LSN: $($LastRestoredLSN)"                        
                        #"$($hdr.firstlsn -le $LastRestoredLSN)"                                                
                        

                        if ($CheckpointLSN -ne $hdr.DatabaseBackupLSN) {
                            Write-Verbose "Skipping $($file) it's not valid for this full backup"
                            continue;
                        }                        

                        #$file.Name
                        #$hdr | select databasename, FirstLSN, lastLSn, DatabaseBackupLSN, DifferentialBaseLSN, CheckpointLSN   | ft -AutoSize
                        #$hdr | gm
                    
                        "Restoring differential for $($dir.name) on $($srvname.servername)"
                        if($PSCmdlet.ShouldProcess($srvname.servername,"Restoring DIFF: $($file) (Last LSN: $($hdr.lastlsn))")) {
                            $res.Action = [Microsoft.SqlServer.Management.Smo.RestoreActionType]::Database
                            $res.NoRecovery = $true
                            $res.database = $dir.name
                            $res.sqlrestore($srv)                                                                               
                        }                        
                        $LastRestoredLSN = $hdr.lastlsn 
                        $diffRestored = $True
                        
                    } # Try
                    catch {                           
                        # Handle the error
                        $err = $_.Exception
                        write-output $err.Message
                        while( $err.InnerException ) {
                                $err = $err.InnerException
                                write-output $err.Message
                            }                        
                    } #Catch   

                } # foreach ($file in $diffFiles)
#>
                # Restore transacation logs if available
                if (test-path "$($livebackuppath)\$($dir.name)\Log\"){
                    RestoreLOGBackups -Server ([ref]$srv) `
                        -dbname $dir.name `
                        -path $livebackuppath `
                        -LastLSN ([ref]$LastRestoredLSN) `
                        #-CheckpointLSN ([ref]$CheckpointLSN)

                }
<#
                $logFiles = Get-ChildItem -Path "$($livebackuppath)\$($dir.name)\LOG\" -file | ? { $_.LastWriteTime -gt (Get-Date).AddYears(-1)} | sort CreationTime 
                if ($logFiles.count -gt 0) {                
                    "Restoring log files for $($dir.name) on $($srvname.servername)"
                }
                foreach ($file in $logFiles) { 
                   # break;
                    try {
                        $res = new-object("Microsoft.SqlServer.Management.Smo.Restore")                                        
                        $res.Devices.AddDevice("$($livebackuppath)\$($dir.name)\LOG\$($file)", [Microsoft.SqlServer.Management.Smo.DeviceType]::File)                       
                    
                        $hdr = $res.ReadBackupHeader($srv)

                        if ($hdr.LastLSN -le $LastRestoredLSN) {                        
                            Write-Verbose "Skipping $($file) it's not valid for this full backup (LastLSN: $($hdr.LastLSN))"
                            continue;
                        }

                        if ($hdr.firstlsn -gt $LastRestoredLSN){
                            Write-Verbose "2Skipping $($file) it's not valid for this full backup (LastLSN: $($hdr.LastLSN))"
                            continue;
                        }                        

                        if($PSCmdlet.ShouldProcess($srvname.servername,"Restoring  LOG: $($file)")) {
                            $res.Action = [Microsoft.SqlServer.Management.Smo.RestoreActionType]::Log
                            $res.NoRecovery = $true
                            $res.database = $dir.name
                            $test = $res.sqlrestore($srv)                                                        
                            #$test
                        }
                        $LastRestoredLSN = $hdr.lastlsn
                    
                    } # Try
                    catch {                           
                        # Handle the error
                        $err = $_.Exception
                        write-output $err.Message
                        while( $err.InnerException ) {
                                $err = $err.InnerException
                                write-output $err.Message
                            }                        
                    } #Catch   
                } # foreach ($file in $logFiles) 
#>
                # bring the database back online
                if($PSCmdlet.ShouldProcess($srvname.servername,"Onlining  $($dir.name)")) {
                    try {
                        $srv.Databases["master"].ExecuteNonQuery("RESTORE DATABASE $($dir.name) WITH RECOVERY")
                    } # Try
                    catch {                           
                        # Handle the error
                        $err = $_.Exception
                        write-output $err.Message
                        while( $err.InnerException ) {
                                $err = $err.InnerException
                                write-output $err.Message
                            }                        
                    } #Catch    
                } # end whatif

            } # foreach ($dir in $dirs)         

        } # if (Test-Path $livebackuppath) 
       
        "`r`n"
    } # foreach ($srvname in $serverList)
}

#ASHDRRestore -RestoreServer "HYRSQL-DR" -RestoreDataBase "ASHApplicationPermissions"   -whatif
#ASHDRRestore -RestoreServer "sqlintra-dr" -RestoreDataBase "ashcore"   -whatif -verbose
#ASHDRRestore -RestoreServer "HYRSQL-DR" -whatif -Verbose -debug
#ASHDRRestore -RestoreServer "HYRSQL-DR" -RestoreDataBase "ASHApplicationPermissions" -verbose

#ASHDRRestore -Verbose

#ASHDRRestore

<#
$serverList = Get-ServerList -cmsName 'tog-sql'  -serverGroup "Prod 2008 DR" -recurse 
$serverList | Format-Table

foreach ($srvname in $serverList) {
    "DR Server: $($srvname.servername)"
    $srv = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $srvname.servername
    #$srv.BackupDirectory
    
    $main = $srvname.servername.Split("{-}")[0]
    "Live server: $main"

    $backupdrive = $srv.BackupDirectory[0]
    #$backupdrive
    
    $livebackuppath = "\\$($srvname.servername)\$($backupdrive)`$\sqldbbackups\$main\"
    $livebackuppath
    Test-Path $livebackuppath


    #$srv.Databases | select Name, CompatibilityLevel, AutoShrink, RecoveryModel, Size, SpaceAvailable | ft -AutoSize
}
#>

#$srv = New-Object Microsoft.SqlServer.Management.Smo.Server "ACNSQL-DR"
#$srv.Databases | select Name

