$NewUser = "CORP\AshithaD"
$CopyFrom = "CORP\ChaitraA"
$ServerNames = @("Migrate")
$DatabaseNames = @("MCLASSECR")

function ASH-CopySQLUser {
    [cmdletbinding(SupportsShouldProcess=$True)]
    param ( 
        [Parameter(Mandatory=$true)][string[]]$ServerNames,
        [Parameter(Mandatory=$true)][string[]]$DatabaseNames,        
        [Parameter(Mandatory=$true)][string[]]$CopyFrom,
        [Parameter(Mandatory=$true)][string[]]$NewUser
        )

    cls
    foreach ($servername in $ServerNames) {
        Write-Verbose "Processing $($servername)"
        $server  = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $servername

        # Check to make sure the new user has an account on the server
        if($server.Logins.Contains($NewUser)) {
                Write-Verbose "`t$($NewUser) exists"
        }
        else {            
            #if (($srv.Logins |Where {($_.LoginType -eq "WindowsUser") -and ($_.Name -eq $username)}) -eq $null) {
            Write-Host "--$($servername) - $($NewUser) Adding login"
            # add login
            if($PSCmdlet.ShouldProcess($servername,"Adding Login:$($NewUser)")) {
                $Login = New-Object ("Microsoft.SqlServer.Management.Smo.Login -ArgumentList") $server, $NewUser
                $Login.LoginType = ‘WindowsUser’
                $login.create()                
            }
        }


        foreach ($DatabaseName in $DatabaseNames) {
            $database = $server.Databases[$DatabaseName]            

            foreach($databasePermission in $database.EnumDatabasePermissions($CopyFrom))
            {
                
                if($PSCmdlet.ShouldProcess("$($servername).$($DatabaseName)","$($databasePermission.PermissionState) $($databasePermission.PermissionType) TO $($NewUser)")) {

                }                
            }


            foreach($objectPermission in $database.EnumObjectPermissions($CopyFrom))
            {
                Write-Host $objectPermission.PermissionState $objectPermission.PermissionType "ON" $objectPermission.ObjectName "TO" $NewUser
            }

            foreach($Role in $database.roles) {
                $rolemembers = $role.EnumMembers()
                if ($rolemembers -contains $CopyFrom) {
                    write-host "EXEC sp_addrolemember N'$($Role.name)', N'$($NewUser)'" 

                } #if ($rolemembers -contains $CopyFrom)

            } # foreach($Role in $database.roles)

        } # foreach ($DatabaseName in $DatabaseNames)

    } # foreach ($servername in $ServerNames)

}

ASH-CopySQLUser `
    -Verbose -whatif `
    -ServerNames:@("Migrate") `
    -DatabaseNames:@("MCLASSECR") `
    -CopyFrom:"CORP\ChaitraA" `
    -NewUser: "CORP\AshithaD"
