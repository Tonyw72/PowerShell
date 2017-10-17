Function Parse-ServerGroup($serverGroup) 
{ 
    $results = $serverGroup.RegisteredServers; 
    foreach($group in $serverGroup.ServerGroups) 
    { 
        $results += Parse-ServerGroup -serverGroup $group; 
    } 
    return $results; 
} 

Function Get-ServerList ([string]$cmsName, [string]$serverGroup, [switch]$recurse) 
{ 
    $connectionString = "data source=$cmsName;initial catalog=master;integrated security=sspi;" 
    $sqlConnection = New-Object ("System.Data.SqlClient.SqlConnection") $connectionstring 
    $conn = New-Object ("Microsoft.SQLServer.Management.common.serverconnection") $sqlconnection 
    $cmsStore = New-Object ("Microsoft.SqlServer.Management.RegisteredServers.RegisteredServersStore") $conn 

    if ($serverGroup) {
        $cmsRootGroup = $cmsStore.ServerGroups["DatabaseEngineServerGroup"].ServerGroups[$serverGroup] 
    }
    else {
        $cmsRootGroup = $cmsStore.ServerGroups["DatabaseEngineServerGroup"].ServerGroups
    }
     
    if($recurse) 
    { 
        return Parse-ServerGroup -serverGroup $cmsRootGroup | select ServerName 
    } 
    else 
    { 
        return $cmsRootGroup.RegisteredServers | select ServerName 
    } 
} 