CLS

$starttime = $(get-date)

$logins = @()
$logins += "CORP\andydadm"
$logins += "CORP\anthonywadm"
$logins += "CORP\briangadm"
$logins += "CORP\crmadmin"
$logins += "CORP\eaontadm"
$logins += "CORP\genetecsqluser"
$logins += "CORP\goodadm"
$logins += "CORP\insqladmin"
$logins += "CORP\johnwadm"
$logins += "CORP\michaelsoadm"
$logins += "CORP\paulvaadm"
$logins += "CORP\sim"
$logins += "CORP\sogadm"
$logins += "CORP\sp-farm"

$servers = Get-SqlRegisteredServerName -SqlServer "tog-SQl" -verbose | 
    Where-Object {$_ -ne "10.8.6.38"} |
    Sort-Object -Unique 

$i = 0
foreach ($server in $servers) {
    Write-Progress -Activity "Checking: $($server)" -PercentComplete ($i/$servers.count*100) 
    $SQLServer = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $server

    $RoleMembers =  $SQLServer.Roles["sysadmin"].EnumMemberNames() 
    #$ServerLogins = $SQLServer.Logins
    
    foreach ($login in $logins) {  
    
        if ($RoleMembers -contains $login -or $RoleMembers.contains($login)) {
            Write-Output "$($server) : $($login) removed from SYSADMIN"   
            #$SQLServer.Roles["sysadmin"].DropMember($login)       
        }        
    }
    $i++
}

write-host "Duration: $((new-timespan $starttime $(get-date)).tostring())"
