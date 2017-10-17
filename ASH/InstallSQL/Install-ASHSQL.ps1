. "$PSScriptRoot\Find-CmsGroup.ps1"
. "$PSScriptRoot\..\functions\Clean-SQLFile.ps1"
. "$PSScriptRoot\..\functions\Install-OlaBackupSolution.ps1"
. "$PSScriptRoot\..\Functions\Send-EmailHTML.ps1"

function Install-ASHSQL {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)][string] $ServerName,
        [validateSet("Developer", "Standard", "Enterprise")]
        [Parameter(Mandatory=$true)][string] $Edition,
        [Parameter(Mandatory=$false)][string] $CMSServer = "TOG-SQL",
        [Parameter(Mandatory=$false)][string] $CMSGroup,
        [Parameter(Mandatory=$false)][string[]] $EmailTestResultsTo = @("anthonyw@ashn.com"),
        [validateSet("16.5.3", "17.2", "17.3")]
        [Parameter(Mandatory=$false)][string] $SSMSVersion,
        [Parameter(Mandatory=$false)][string] $SSMSPath,
        [Switch]$NoInstall,
        [switch]$NoRegister,
        [switch]$NoConfig,
        [switch]$NoOLA,
        [switch]$NoSSMS
    )

    begin{
        #$servername  = "SD-P-FINSQL1"
        if (-not $NoInstall){
            $password = Read-Host -Prompt "Please enter the password for the SQL service account" #-AsSecureString
        }        

        if ($SSMSPath -eq "") {
            
            switch ($SSMSVersion) {
                "16.5.3" {
                    $SSMSPath = "\\sd-tog\sog\Apps\Microsoft\SQL Server\SSMS\SSMS 16.5.3\SSMS-Setup-ENU.exe"
                }
                "17.2" {
                    $SSMSPath = "\\sd-tog\sog\Apps\Microsoft\SQL Server\SSMS\SSMS 17.2\SSMS-Setup-ENU17_2.exe"
                }
                "17.3" {
                    $SSMSPath = "\\sd-tog\sog\Apps\Microsoft\SQL Server\SSMS\SSMS 17.3\SSMS-Setup-17_3.exe"
                }
                default {
                    $SSMSPath = "\\sd-tog\sog\Apps\Microsoft\SQL Server\SSMS\SSMS 17.3\SSMS-Setup-17_3.exe"
                }
            }        
        }

        $updatesource = "\\sd-tog\SOG\Apps\Microsoft\SQL Server\SQL Server 2016\Cummulative Updates"

        switch ($Edition) {
            "Developer" {
                $installPath = "\\sd-tog\sog\Apps\Microsoft\SQL Server\SQL Server 2016\SQL Server 2016 dev\setup.exe"
                $ConfigPath = "\\sd-tog\sog\Apps\Microsoft\SQL Server\SQL Server 2016\dev ConfigurationFile.ini"
            }
            "Standard" {
                $installPath = "\\sd-tog\sog\Apps\Microsoft\SQL Server\SQL Server 2016\SQL Server 2016 SE\setup.exe"
                $ConfigPath = "\\sd-tog\sog\Apps\Microsoft\SQL Server\SQL Server 2016\STD ConfigurationFile.ini"
            }
            "Enterprise" {
                $installPath = "\\sd-tog\sog\Apps\Microsoft\SQL Server\SQL Server 2016\SQL Server 2016 EE\setup.exe"
                $ConfigPath = "\\sd-tog\sog\Apps\Microsoft\SQL Server\SQL Server 2016\STD ConfigurationFile.ini"
            }
        }

        Write-Verbose "$installPath - $(Test-Path $installPath)"
        Write-Verbose "$ConfigPath - $(Test-Path $ConfigPath)"
    }

    process {
        if (-not $NoInstall) {
            if($PSCmdlet.ShouldProcess("$($ServerName)","Installing SQL Server")){
                $install = "start-process -wait -verb runas -filepath ""$($installPath)"" -ArgumentList @('/ConfigurationFile=""$($ConfigPath)""', '/SQLSVCPASSWORD=""$($password)""', '/AGTSVCPASSWORD=""$($password)""', '/UpdateSource=""$($updatesource)""', '/IACCEPTSQLSERVERLICENSETERMS')  "
                $env:SEE_MASK_NOZONECHECKS = 1
                Invoke-Expression $install 
            }
        }

        if (-not $NoRegister -and $CMSGroup){
            # Connect to the CMS Server and get the Registers Server Store
            $sqlcms = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $CMSServer
            $store = New-Object Microsoft.SqlServer.Management.RegisteredServers.RegisteredServersStore($sqlcms.ConnectionContext.SqlConnectionObject)

            # Make sure that the requested folder exists
            $cms = Find-CmsGroup -CmsGrp $store.DatabaseEngineServerGroup.ServerGroups -Stopat $CMSGroup
            if($null -eq $cms) {
                Write-Error "No Groups found matching $CMSGroup"
            }
            else {
                if($PSCmdlet.ShouldProcess("$($CMSServer)","Registering $($ServerName) to: $($CMSGroup)")){
                    $newserver = New-Object Microsoft.SqlServer.Management.RegisteredServers.RegisteredServer($cms, $servername)
                    $newserver.ServerName = $servername
                    $newserver.Description = $servername
                    $newserver.Create()
                }
            }

            
        }

        if (-not $NoConfig){
            $path = "\\sd-tog\sog\Apps\Microsoft\SQL Server\Scripts\Post Install Scripts\"
            $files = @()
            $files +=  "SQL 2014 New Setup.sql"
            $files +=  "002_Admin_DBA_Set_Model_File_Sizes.sql"
            $files +=  "002b Add Agent Operator.sql"
            $files +=  "003_Admin_DBA_Cycle_Errorlog.sql"                    
            $files +=  "004_Mail_Display_Name_Update.sql"                    
            $files +=  "005_Admin_DBA_Delete_Backup_History.sql"             
            $files +=  "006_Create_Function_fn_split_inline_CTE.sql"         
            $files +=  "007_DBA_CopyLogins.sql"                                          
            $files +=  "008_sp_Hexadecimal.sql"                              
            $files +=  "008b_sp_help_revlogin.sql"                           
            $files +=  "009_sp_Help_Revlogin_Mod.sql"                        
            $files +=  "010 Optimize for Ad Hoc workloads.sql"               
            $files +=  "010 sp_killall.sql"
            $files += "Create SQL Server Alerts.sql"                        
            $files += "DDL_Database_ALTERED_Trigger.sql"                    
            $files += "DDL_Database_Attemped_DROP_Trigger.sql"              
            $files += "DDL_Database_DROPPED_Trigger.sql"                    
            $files += "Enable XP_cmdshell.sql"                              
            $files += "Event Notification - Configure Autogrowth Alerts.sql"
            $files += "IndexOptimize - USER_DATABASES INDEXES ONLY.sql" 
            $files += "Set up TempDB Alert and Scheduled Job.sql"           
            $files += "sp_help_revlogin2.sql"                               
            $files += "sp_sqlskills_exposecolsinindexlevels.sql"            
            $files += "sp_sqlskills_sql2012_helpindex.sql"                  
            $files += "sp_who3.sql"   
            $files += "who_is_active_v11_11.sql"     

            Execute-SQLFile -ServerName $ServerName -Filenames $files -Path $path   
            
            if($PSCmdlet.ShouldProcess("$($servername)","Applying T3226 and restarting the service.")){
                $SQLSvc = (get-item -Path "SQLSERVER:\SQL\localhost\").ManagedComputer.Services["MSSQLSERVER"]
                $SQLSvc.Refresh()
                $SQLSvc.StartupParameters += ";-T3226"
                $SQLSvc.alter()
                
                Restart-Service "MSSQLSERVER" -Force

                Start-Sleep -Seconds 30 
            }
        }

        if (-not $NoOLA) {
            $share = . "$PSScriptRoot\..\cmdlets\Find-EmptyBackupShare.ps1"            
            Install-OlaBackupSolution -SqlServer $servername `
                -backupdir $share `
                -CleanupTime 192 `
                -Schedule "\\sd-tog\SOG\Apps\Microsoft\SQL Server\Scripts\Post Install Scripts\001b_ASH_OlaSchedule.sql" `
                -Alerts "\\sd-tog\SOG\Apps\Microsoft\SQL Server\Scripts\Post Install Scripts\001a_ASH_OlaNotifications.sql" `
                -StartSystem `
                -StartFull                
        }

        if (-not $NoSSMS){
            if ($PSCmdlet.ShouldProcess("$($Servername)", "Installing SSMS")){
                $install = "start-process -wait -verb runas -filepath ""$($SSMSPath)"" -ArgumentList @('/install', '/passive', '/norestart')  "
                $env:SEE_MASK_NOZONECHECKS = 1
                Invoke-Expression $install 
            }
        }
    }
}

Function Execute-SQLFile{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)][string[]] $Filenames,
        [Parameter(Mandatory=$true)][string] $Path,
        [Parameter(Mandatory=$true)][string] $ServerName
    )
    begin {
        $ConnectionString = "Server = $ServerName ; Database = master; Integrated Security = True;"
        $Connection = New-Object System.Data.SQLClient.SQLConnection 
        $Connection.ConnectionString = $ConnectionString      
        $Connection.Open();

        $Command = New-Object System.Data.SQLClient.SQLCommand 
        $Command.Connection = $Connection
    }

    Process {
        foreach ($file in $Filenames) {
            $fullpath = "$($path)$($file)"               
            if($PSCmdlet.ShouldProcess("$($servername)","Executing: $($fullpath)")){
                Write-Verbose "Executing $($file)"        
                $script = Clean-SQLFile $fullpath           
        
                foreach ($scriptpart in $script){    
                    if ($scriptpart.scriptpart) {                        
                        $Command.CommandText = $($scriptpart.scriptpart)
                        $niks = $Command.ExecuteNonQuery();           
                    }
                }
            }
        }
    }

    end {
        $connection.close()
    }

}