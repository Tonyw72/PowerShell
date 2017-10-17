Function Add-SQLPermissions {
    <#
    .SYNOPSIS
        Adds Active Directory users or groups to specided Server, Database, and Roles
    .DESCRIPTION
        This funtion will loop through all of the servers/databases and add the specifed Active Directory users/groups to the requested roles. It will also create the ASH Developer & ASH Data Architect roles if necessary.
    .PARAMETER Databases
        Array of the dataases to grant role membership in. If omitted, then all user databases on the server(s) will be used.
    .EXAMPLE
        C:\PS>
        Example of how to use this cmdlet
    .EXAMPLE
        C:\PS>
        Another example of how to use this cmdlet
    .INPUTS
        Inputs to this cmdlet (if any)
    .OUTPUTS
        Output from this cmdlet (if any)
    .NOTES
        General notes
    .COMPONENT
        Created by Tony Wilhelm 2017-09-14
    .ROLE
        The role this cmdlet belongs to
    .FUNCTIONALITY
        The functionality that best describes this cmdlet
    #>
    [cmdletbinding(SupportsShouldProcess=$True)]
    param ( 
        [Parameter(Mandatory=$true)][string[]]$ServerNames,
        [Parameter(Mandatory=$false)][string[]]$Databases,        
        [Parameter(Mandatory=$true)][string[]]$UserNames,
        [Parameter(Mandatory=$true)][string[]]$AddRoles,
        [bool]$NoScript =$false
        )

    $choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
    $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
    $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))

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
                    $Login.LoginType = "WindowsUser"
                    #$login.DefaultDatabase = "$($servername)"
                    if ($NoScript) {
                        $login.create()
                    }
                    else {
                        $login.script()                        
                    }
                }
            }

            if ($Databases.Count-eq 0) {
                Write-Output "`t`tGranting for all user databases"

                $Databases = Get-DbaDatabase -SqlServer $servername -NoSystemDb | 
                    Select-Object -expand Name 
            }

            # Loop thrrough the list of databases
            foreach($dbname in $Databases) {
                write-verbose "`t`t`tChecking $($dbname)"
                $WasReadOnly = $false

                $db = $srv.databases["$($dbname)"]

                if ($db.Readonly -eq $true) {
                    Write-Verbose "$($db.name) is read-only"
                    $message  = "Database Read-Only"
                    $question = "Do you want to continue?"
                    $decision = $Host.UI.PromptForChoice($message, $question, $choices, 0)

                    if ($decision -eq 0) {     
                        $WasReadOnly = $true          
                        $db.readonly = $false
                        $db.alter()    
                    }
                    else {
                        continue
                    }
                }

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

                    #add the ADH Application role if necessary
                    if ($rolename -eq "ASH Application" -and -not $db.Roles.Contains($rolename)) {
                        if($PSCmdlet.ShouldProcess("$($servername) - $($dbname)","Adding role: $($rolename)")) {
                            #create the role
                            Write-Output "`tCreating the $($rolename) role (db_datawriter, db_datareader, Execute, ViewDefinition, and ShowPlan)"
                        
                            $role = New-Object('Microsoft.SqlServer.Management.smo.DatabaseRole') $db, $roleName
	                        $role.Create();

                            $objDbPerms = New-Object Microsoft.SqlServer.Management.Smo.DatabasePermissionSet 
	                        $objDbPerms.Execute = $true
                            $objDbPerms.Showplan = $true
                            $objDbPerms.ViewDefinition = $true    
	                        $db.Grant($objDbPerms, $roleName);
                            
                            $db.Roles["db_datareader"].AddMember($rolename)
                            $db.Roles["db_datawriter"].AddMember($rolename)                            
                        }
                    }

                    #add the "ASH Developer" role if necessary
                    if ($rolename -eq "ASH Developer" -and -not $db.Roles.Contains($rolename)) {
  
                        if($PSCmdlet.ShouldProcess("$($servername) - $($dbname)","Adding role: $($rolename)")) {
                            #create the role
                            Write-Output "`tCreating the $($rolename) role (db_ddladmin, db_datawriter, db_datareader, Execute, ViewDefinition, and ShowPlan)"
                        
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
                    }

                    # Add the ASH Data Architect Role
                    if ($rolename -eq "ASH Data Architect" -and -not $db.Roles.Contains($rolename)) {
                        
                        if($PSCmdlet.ShouldProcess("$($servername) - $($dbname)","Adding role: $($rolename)")) {
                            #create the role
                            Write-Output "`tCreating the $($rolename) role (db_datareader, ViewDefinition, and ShowPlan)"
                        
                            $role = New-Object('Microsoft.SqlServer.Management.smo.DatabaseRole') $db, $roleName
	                        $role.Create();

                            $objDbPerms = New-Object Microsoft.SqlServer.Management.Smo.DatabasePermissionSet 
                            #$objDbPerms.Execute = $true	                    
                            $objDbPerms.Showplan = $true
                            $objDbPerms.ViewDefinition = $true    
	                        $db.Grant($objDbPerms, $roleName)

                            $db.Roles["db_datareader"].AddMember($rolename)                               
                        }
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
                            if($PSCmdlet.ShouldProcess("$($servername) - $($dbname)", "Adding user $($username) to $rolename")) {
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
                            if($PSCmdlet.ShouldProcess("$($servername) - $($dbname)", "Adding user $($username) to $rolename")) {
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

                # if the database was readonly prior, set it back
                if ($WasReadOnly  -eq $true) {
                    $db.close()
                    $db.readonly = $false
                    $db.alter()
                }

            } # foreach($dbname in $Databases)

        } # foreach ($username in $usernames)

        Write-Verbose "`r`n"
    } # foreach($svr in $servername)
}