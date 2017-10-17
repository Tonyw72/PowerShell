Function AddPermissions {
    [cmdletbinding(SupportsShouldProcess=$True)]
    param ( 
        [Parameter(Mandatory=$true)][string[]]$servernames,
        [Parameter(Mandatory=$false)][string[]]$dbnames,        
        [Parameter(Mandatory=$true)][string[]]$usernames,
        [Parameter(Mandatory=$true)][string[]]$AddRoles,
        [bool]$NoScript =$false
        )

    foreach($servername in $servernames) {
        Write-Verbose "Processing $($servername)"

        $srv = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $servername

        #$logins = $srv.Logins
        #$logins 

        foreach ($username in $usernames) {
            #WRITE-HOST "`tChecking $($username)"

            if($srv.Logins.Contains($username)) {
                Write-Verbose "`t$($username) exists"
            }
            else {
            
            #if (($srv.Logins |Where {($_.LoginType -eq "WindowsUser") -and ($_.Name -eq $username)}) -eq $null) {
                Write-Host "--$($servername) - $($username) Adding login"
                # add login
                if($PSCmdlet.ShouldProcess($servername,"Adding Login:$($username)")) {
                    $Login = New-Object ("Microsoft.SqlServer.Management.Smo.Login -ArgumentList") $srv, $username
                    $Login.LoginType = ‘WindowsUser’
                    #$login.DefaultDatabase = "$($servername)"
                    if ($NoScript) {
                        $login.create()
                    }
                    else {
                        $login.script()                        
                    }
                }
            }

            if ($dbnames.Count-eq 0) {
                Write-Output "`t`tGranting for all user databases"

                $dbnames = Get-DbaDatabase -SqlServer $servername -NoSystemDb | SELECT -expand Name 
            }

            # Loop thrrough the list of databases
            foreach($dbname in $dbnames) {
                write-verbose "`t`t`tChecking $($dbname)"

                $db = $srv.databases["$($dbname)"]

                if($db.Users.Contains($username)) {
                    Write-Verbose "`t`t$($username) exists"
                    
                    #check to make sure the user has connect to rights
                    $user = $db.users[$username]

                    #$user| gm

                    if ($user.hasdbaccess){
                        Write-Verbose "`t`t$($username) can connect to this database"
                    }
                    else {
                        Write-Verbose "`t`t$($username) can't connect to this database"
                        $perm = New-Object('Microsoft.SqlServer.Management.Smo.DatabasePermissionSet')
                        $perm.Connect = $True;
                        if($PSCmdlet.ShouldProcess($servername,"Granting connect to:$($username)")) {                        
                            if ($NoScript) {
                                #$db | gm
                                $db.grant($perm, $user.name)
                                #$user.alter()
                                #$perm
                                #$username
                                #$user.script()
                            }
                            else {    
                                "USE $($dbname)"                            
                                "GRANT CONNECT TO $($username)"                                                                
                                "GO"
                            }
                        }
                    }
                }
                else { # Add database user
                    Write-Host "--$($servername).$($dbname) - $($username) Adding database user"
                    if($PSCmdlet.ShouldProcess($servername,"Adding Login:$($username)")) {
                        $usr = New-Object ('Microsoft.SqlServer.Management.Smo.User') ($db, $username)
                        $usr.Login = $username
                        if ($NoScript) {
                            $usr.create()
                        }
                        else {                            
                            $usr.script()                            
                        }
                    }
                }

                #loop through the roles
                foreach ($rolename in $addroles) {

                    #add the "ASH Developer" role if necessary
                    if ($rolename -eq "ASH Developer" -and -not $db.Roles.Contains($rolename)) {
  
                        #create the role
                        Write-Verbose "`tCreating the $($rolename) role"
                        
                        $role = New-Object('Microsoft.SqlServer.Management.smo.DatabaseRole') $db, $roleName
	                    $role.Create();

                        $objDbPerms = New-Object Microsoft.SqlServer.Management.Smo.DatabasePermissionSet 
	                    $objDbPerms.Execute = $true
                        $objDbPerms.Showplan = $true
                        $objDbPerms.ViewDefinition = $true    
	                    $db.Grant($objDbPerms, $roleName);

                        $db.Roles["db_ddladmin"].AddMember($rolename)
                        $db.Roles["db_datareader"].AddMember($rolename)
                        $db.Roles["db_datawriter"].AddMember($rolename)                            
                    }
                    
                    <#
                    if ($user.IsMember($rolename)) {
                        Write-Verbose "`t`t$($username) is in $($rolename)"
                    }
                    else {
                        Write-Host "--$($servername).$($dbname) - $($username) Adding user to $($rolename)"
                        if($PSCmdlet.ShouldProcess($servername,"Adding user $($username) to $rolename")) {                            
                            if ($NoScript) {
                                $user.AddToRole($rolename)
                            }
                            else {
                                "USE $($dbname)"
                                "EXEC sp_addrolemember N'$($rolename)', N'$($username)'"                                
                                "GO"
                            }
                        }
                    }
                    #>

                    if (!($db.Roles.Contains($rolename))) #Check to see if the role already exists in the database
                    {
                        Write-Error "CRAP - role doesn't exist"
                    }
                    else {
                        $role = $db.Roles[$rolename]

                        if($role.EnumMembers().count -eq 0) {
                            Write-Host "--$($servername).$($dbname) - $($username) Adding user to $($rolename)"
                            if($PSCmdlet.ShouldProcess($servername,"Adding user $($username) to $rolename")) {
                                #$role.AddMember($username)
                                if ($NoScript) {
                                    $role.AddMember($username)
                                }
                                else {
                                    "USE $($dbname)"
                                    "EXEC sp_addrolemember N'$($rolename)', N'$($username)'"                                
                                    "GO"
                                }
                            }
                        }
                        elseif($role.EnumMembers().ToLower().contains($username.ToLower())) {
                            Write-Verbose "`t`t$($username) is in $($rolename)"
                        }
                        else {
                            Write-Host "--$($servername).$($dbname) - $($username) Adding user to $($rolename)"
                            if($PSCmdlet.ShouldProcess($servername,"Adding user $($username) to $rolename")) {
                                #$role.AddMember($username)
                                if ($NoScript) {
                                    $role.AddMember($username)
                                }
                                else {
                                    "USE $($dbname)"
                                    "EXEC sp_addrolemember N'$($rolename)', N'$($username)'"                                
                                    "GO"
                                }
                            }
                        }
                    }

                } # foreach ($role in $addroles) 

            } # foreach($dbname in $dbnames)

        } # foreach ($username in $usernames)

        Write-Verbose "`r`n"
    } # foreach($svr in $servername)
}

$serverList = @()
#$serverList += "ASH_DEV"
#$serverList += "ashb-dev"
#$serverList += "ASHBI-PRD1"
#$serverList += "ashb-sql"
#$serverList += "ASHCMS" 
#$serverList += "ASH-DWREPORTS"
#$serverList += "ASH-EDIREPORTS"
#$serverList += "ASH-STG"
#$serverList += "ASH-STG1"
#$serverList += "ash-stgsql"
#$serverList += "ASHSQL-Reports"
#$serverList += "EDI-2008"
#$serverList += "FIT-DEVSQL"
#$serverList += "FIT-STGSQL"
#$serverList += "HRLREPORTS-2008"
#$serverList += "hyrsql"
#$serverList += "intra-dev1"
#$serverList += "SD-ASHBSTG"
#$serverList += "SD-D-ACNSQL"
#$serverList += "SD-D-MICCSQL"
#$serverList += "SD-D-PROVSCHSQL"
#$serverList += "SD-HYRDEV"
#$serverList += "SD-HYRSTG"
$serverList += "SD-P-PROVSCHSQL"
#$serverList += "SD-P-SEPM"
#$serverList += "SD-S-ACNSQL"
#$serverList += "SD-S-ProvSchSQL"
#$serverList += "SD-T-DBA1"
#$serverList += "SD-T-DBA2"
#$serverList += "SD-T-DBA3"
#$serverList += "SQL-HRTEST08"
#$serverList += "sqlintra"
#$serverList += "sql-reports08"
#$serverList += "stg-desktop"
#$serverList += "STG-HRLREP08"
#$serverList +="TESTASHLINKSQL"

$userList = @()
#$userList += "activityfeed_webuser"
#$userList += "ashcore_web_user"
#$userList += "ashlink_user"
#$userList += "CORP\AbayomiA"
#$userList += "CORP\AdamS"
#$userList += "CORP\AdrienneB"
#$userList += "CORP\AnaJ"
#$userList += "CORP\AndreaI"
#$userList += "CORP\AndrewH"
$userList += "CORP\AndrewG"
#$userList += "CORP\AndriyM"
#$userList += "CORP\AngelineP"
#$userList += "CORP\ArchanaG"
#$userList += "CORP\ArthurL"
#$userList += "CORP\AshankB"
#$userList += "CORP\AshithaD"
#$userList += "CORP\AutumnP"
#$userList += "CORP\BrendanM"
#$userList += "CORP\CarloP"
#$userList += "CORP\ChandanaA"
#$userList += "CORP\ChrisH"
#$userList += "CORP\DeepaV"
#$userList += "CORP\DarrenW"
#$userList += "CORP\DeniseB"
#$userList += "CORP\EarlL"
#$userList += "CORP\EmekaE"
#$userList += "CORP\EricH"
#$userList += "CORP\GabeG"
#$userList += "CORP\GayathriG"
#$userList += "CORP\HareeshL"
#$userList += "CORP\HuG"
#$userList += "CORP\IanB"
#$userList += "CORP\IsaacC" 
#$userList += "CORP\IMDBIAnalyst"
#$userList += "CORP\JasonW"
#$userList += "CORP\JessicaBr"
#$userList += "CORP\JessieH"
#$userList += "CORP\JustinM"
#$userList += "CORP\JustinY"
#$userList += "CORP\KatyC"
#$userList += "CORP\KevinH"
#$userList += "CORP\KhoaN"
#$userList += "CORP\KristineB"
#$userList += "CORP\LanL"
#$userList += "CORP\LaureR"
#$userList += "CORP\LisaraeH"
#$userList += "CORP\LoreyneH"
#$userList += "CORP\ManmaiY"
#$userList += "CORP\MarcA"
#$userList += "CORP\MarkM"
#$userList += "CORP\MattL"
#$userList += "CORP\MercedesR"
#$userList += "CORP\MichaelA"
#$userList += "CORP\MichaelLyons"
#$userList += "CORP\Michaels"
#$userList += "CORP\MicheleS"
#$userList += "CORP\NickD"
#$userList += "CORP\PamJ"
#$userList += "CORP\PulkitA"
#$userList += "CORP\RamyaR"
#$userList += "CORP\RinehartE"
#$userList += "CORP\RitchieM"
#$userList += "CORP\SayaliP"
#$userList += "CORP\ShaunM"
#$userList += "CORP\SheriF"
#$userList += "CORP\ShivangiD"
#$userList += "CORP\ShuL"
#$userList += "CORP\SydD"
#$userList += "CORP\tableau"
#$userList += "CORP\TashaG"
#$userList += "CORP\ThoL"
#$userList += "CORP\ThyL"
#$userList += "CORP\TravisM"
#$userList += "CORP\VaniM"
#$userList += "CORP\VincentS"
#$userList += "CORP\VinhN"
#$userList += "CORP\WenQ"
#$userList += "CORP\WilliamPe"
#$userList += "edi_speed_user"
#$userList += "IMB_Reports_User"
#$userList += "RinehartE"
#$userList += "svcsepprosoc"

$dbList = @()
#$dbList += "ActivityFeed"
#$dbList += "Archive"
#$dbList += "ASHCore"
#$dbList += "ASHApplicationPermissions"
#$dbList += "Benefits"
#$dbList += "Benefits_Archive"
#$dbList += "CAP_Archive"
#$dbList += "CAP_Audit"
#$dbList += "CAP_Benefits"
#$dbList += "CAP_Finance"
#$dbList += "CAP_Process"
#$dbList += "CAP_Recon"
#$dbList += "CAP_Test"
#$dbList += "CCMData"
#$dbList += "CCMStatisticalData"
#$dbList += "ChooseHealthy"
#$dbList += "CoachingActionPlan"
#$dbList += "CoachMessenger"
#$dbList += "Commlog"
#$dbList += "Corporate"
#$dbList += "CustomerService"
#$dbList += "DA_Development"
#$dbList += "DA_DW"
#$dbList += "DA_Production"
#$dbList += "DA_Reports"
#$dbList += "DataVault"
#$dbList += "dbs_ihis"
#$dbList += "dbs_ihis_arch2014"
#$dbList += "dbs_ihis_arch2016"
#$dbList += "DW_ASHB"
#$dbList += "DW_ASHLink"
#$dbList += "DW_Clinical"
#$dbList += "DW_Commlog"
#$dbList += "DW_Finance"
#$dbList += "DW_Fitness"
#$dbList += "DW_Provider"
#$dbList += "DW_Shared"
#$dbList += "DW_Stg"
#$dbList += "ege_process"
#$dbList += "EDI_Archive"
#$dbList += "EDI_hrl"
#$dbList += "EDI_Prod"
#$dbList += "Elig"
#$dbList += "Elig_HRL_Process"
#$dbList += "Elig_reports"
#$dbList += "EmpoweredDecisions"
#$dbList += "Engage"
#$dbList += "ExerciseRewards"
#$dbList += "Experience"
#$dbList += "ExternalData"
#$dbList += "Finance_rates"
#$dbList += "Fitness"
#$dbList += "FitnessEngagement"
#$dbList += "FitnessReports"
#$dbList += "FTP_Process"
#$dbList += "HealthTrackers"
#$dbList += "Healthyroads"
#$dbList += "HEALTHYSTORE"
#$dbList += "HP_benefits"
#$dbList += "HP_Process"
#$dbList += "HRAQUIZ"
#$dbList += "HRLDW"
#$dbList += "HRMS"
#$dbList += "IMB_Reports"
#$dbList += "IMB_Archive"
#$dbList += "IMBProd"
#$dbList += "IMB_Reports"
#$dbList += "IMD_Reports"
#$dbList += "IMD_Reports_AdHoc"
#$dbList += "IMD_Reports_Temp"
#$dbList += "IMDProviderArchive"
#$dbList += "IMDProviderReports"
#$dbList += "Incentive"
#$dbList += "Inspiration"
#$dbList += "Intranet"
#$dbList += "MClassEcr"
#$dbList += "MICC"
#$dbList += "Morpheus"
#$dbList += "msdb"
#$dbList += "NewASHB"
#$dbList += "NewASHB_Archive"
#$dbList += "NewASHBUnitTesting"
#$dbList += "News"
#$dbList += "PGRNTS"
#$dbList += "PGRNTS_DEV"
#$dbList += "Promis"
#$dbList += "ProviderSearch"
#$dbList += "ProviderSearchTest"
#$dbList += "PSCCMDATA" 
#$dbList += "PSTDS"
#$dbList += "PSTDS_dev"
#$dbList += "ResourceLibrary"
#$dbList += "ReportServer"
#$dbList += "sem5"
#$dbList += "sem6"
#$dbList += "SilverandFit"
#$dbList += "SilverSteps"
#$dbList += "Ticketing"
#$dbList += "Tridion11_cm"
#$dbList += "Toga"
#$dbList += "Tools"
#$dbList += "UserManagement"
#$dbList += "Z_archive"

$roleList = @()
$roleList += "db_datareader"
#$roleList += "db_datawriter"
#$roleList += "db_ddladmin"
#$roleList += "db_accessadmin"
#$roleList += "db_securityadmin"
#$roleList += "db_owner"
#$roleList += "SQLAgentReaderRole"
#$roleList += "ASH Developer" # includes db_ddladmin, db_datareader, db_datawriter, ViewDefinition, ShowPlan and Execute
#$roleList += "ECR_Administrator"
#$roleList += "ECR_Inquiry"	
#$roleList += "ECR_Nurse"	
#$roleList += "ECR_Supervisor"
#$roleList += "ECR_Tester"
#$roleList += "ECR_User"
#$roleList += "TriageTeam"
#$roleList += "CaseReviewCommittee"
#$roleList += "CaseReviewInquiry"


#$dbList = @("Benefits") #, "ChooseHealthy", "ExerciseRewards", "Fitness", "FitnessEngagement", "ProviderSearch", "SilverandFit", "SilverSteps") #, "", "StealthAudit")
#$dbList = @("Benefits")
#$roleList = @("db_datareader") #, "db_datawriter") #db_datareader, db_datawriter, db_owner

AddPermissions `
    -servernames $serverList `
    -dbnames $dbList  `
    -usernames $userList  `
    -AddRoles $roleList  `
    -NoScript $true #-Verbose -WhatIf


