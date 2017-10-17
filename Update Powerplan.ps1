. "\\tog-sql\SOG\Apps\Microsoft\SQL Server\Powershell\Scripts\get-serverlist.ps1"

$cmsName = 'TOG-SQL'

$connectionString = "data source=$cmsName;initial catalog=master;integrated security=sspi;" 
$sqlConnection = New-Object ("System.Data.SqlClient.SqlConnection") $connectionstring 
$conn = New-Object ("Microsoft.SQLServer.Management.common.serverconnection") $sqlconnection 
$cmsStore = New-Object ("Microsoft.SqlServer.Management.RegisteredServers.RegisteredServersStore") $conn 
$cmsRootGroup = $cmsStore.ServerGroups["DatabaseEngineServerGroup"].ServerGroups

$serverlist = @()
$count =0

$AutoFix = $false

Get-ServerList -cmsName $cmsName -recurse | foreach -process { $ServerList += $_.servername}

$serverlist = $serverlist | Sort-Object -unique
cls
foreach($ServerName in $ServerList) {
    
    $server  = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $ServerName
    $plan = Test-DbaPowerPlan -ComputerName $server.name -Detailed
    
    if ($plan.ActivePowerPlan -eq "Balanced") {        
        #Write-Output "$($server.name) - $($plan.ActivePowerPlan)"
        set-dbapowerplan -computername $server.name #-whatif
    }

} # foreach($svr in $ServerList) 