function ASH-NewADGroup {
    [cmdletbinding(SupportsShouldProcess=$True)]
    param (
        [Parameter(Mandatory=$true)][string]$username,
        [string] $Path,
        [Parameter(Mandatory=$true)][ref]$Server,
        [string] $ServerName,
        [string] $DatabaseName,
        [string] $Permission
    )

    $svr = $Server.value 
    $ADGroup = "$($ServerName) $($DatabaseName) $($Permission)"
    $description = "Users that need to have $($Permission) access to $($DatabaseName)"
    
    # check to see if the group exists yet
    $g = Get-ADGroup -filter {name  -eq $ADGroup}
    if ($g -eq $null) {
        Write-Verbose "`t`t`tCreate Group: $($ADGroup)"

        New-ADGroup -Name $ADGroup -Path:"$($Path)" -GroupScope:'Global' -GroupCategory:'Security'  `
            -Description:$description `
            -WhatIf:([bool]$WhatIfPreference.IsPresent)
    }

    <#
    $g = Get-ADGroup -filter {name  -eq $ADGroup}    
    if ($g -ne $null) {
        Write-Verbose "`t`t`tAdd $($username) to $($ADGroup)"

        Add-ADGroupMember -Identity:"$($ADGroup)" -Members:$username.Split('\')[1] `
            -WhatIf -ErrorAction: SilentlyContinue
    }
    #>
}

function ASH-ChangeToActiveDirectorySecurity {
    [cmdletbinding(SupportsShouldProcess=$True)]
    param (
        [String[]] $ServerGroups,
        [String[]] $ServerList,
        [string] $Path = 'ou=Groups - Security,dc=corp,DC=ashn,DC=com',
        [string] $NewOU = "SQL-Security"
    )

    # Check to see if the OU greoup exists
    if (-not [adsi]::Exists("LDAP://ou=$($NewOU),$($Path)")) {
        Write-Verbose "Create new OU: ou=$($NewOU),$($Path)"
        [bool]$WhatIfPreference.IsPresent
        New-ADOrganizationalUnit -Name:$NewOU -Path:$Path -WhatIf:([bool]$WhatIfPreference.IsPresent)
    }

    #Get servers to check 


    foreach ($servername in $serverlist) {
        Write-Verbose "Processing $($servername)"

        # Connect to the SQL server
        $server  = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $ServerName

        #loop through the databases
        foreach ($db in $server.databases) {
            Write-Verbose "`t$($db.name)"

            #Loop through the AD users
            foreach ($user in $db.users | where {$_.name -like "CORP\*"}) {
                Write-Verbose "`t`t$($user.name)"

                # Add to AD role for
                foreach($databasePermission in $db.EnumDatabasePermissions($user.Name)) {        
                    if ("$($databasePermission.PermissionType)" -ne "CONNECT") {                        
                        Write-Verbose "`t`t`t$($databasePermission.PermissionState) $($databasePermission.PermissionType) TO $($databasePermission.Grantee)"
                        ASH-NewADGroup -Path:"ou=$($NewOU),$($Path)" `
                            -username:$user.name `
                            -servername:$ServerName `
                            -DatabaseName:$db.name `
                            -Permission: "$($databasePermission.PermissionType)" `
                            -Server:([ref]$Server) `
                            -WhatIf:([bool]$WhatIfPreference.IsPresent)
                    }
                }

    <#                        
    foreach($objectPermission in $db.EnumObjectPermissions($user.Name)) {
        Write-Host $objectPermission.PermissionState $objectPermission.PermissionType "ON" $objectPermission.ObjectName "TO" $objectPermission.Grantee
    }
    #>

                foreach($role in $db.roles | where{$_.enumMembers().contains($user.name)}) {
                    Write-Verbose "$($user.name) is a member of $($role.name)"
                    ASH-NewADGroup -Path:"ou=$($NewOU),$($Path)" `
                            -username:$user.name `
                            -servername:$ServerName `
                            -DatabaseName:$db.name `
                            -Permission: "$($role.name)" `
                            -Server:([ref]$Server) `
                            -WhatIf:([bool]$WhatIfPreference.IsPresent)
                }
    
    
                foreach($databasePermission in $db.EnumDatabasePermissions($user.Name)) {
                    #if (-not $databasePermission.PermissionType -eq "CONNECT") {
                        #Write-Verbose "`t`t$($databasePermission.PermissionState) '$($databasePermission.PermissionType)' TO $($databasePermission.Grantee)"
                        #$ADGroup = "$($servername)_$($db.name)_$($databasePermission.PermissionType)"

                        

                    
                        <#
                        $g = Get-ADGroup -filter {name  -eq $ADGroup}
                        if ($g -eq $null -and -not $($databasePermission.PermissionType) -eq "CONNECT") {
                            New-ADGroup -Name $ADGroup -Path:"$($NewOU),$($Path)" -GroupScope:'Global' -GroupCategory:'Security' `
                                -WhatIf
                        }
                        #>
                    #}
                        
                }

                # loop though the roles
                #foreach ($role in $user.EnumRoles()) {
                #    Write-Verbose "`t`t`t$($role.name)"
                #}
                
            } # foreach ($user in $db.users
            
            
        } # foreach ($db in $server.databases)
    
    } # foreach ($servername in $serverlist)
}

$servers = @("SQL-HRTEST08")
ash-ChangeToActiveDirectorySecurity -ServerList:$servers -Verbose | 
    tee "c:\ASH-ChangeToActiveDirectorySecurity $(get-date -Format "yyyy-MM-dd HHmmss").txt"