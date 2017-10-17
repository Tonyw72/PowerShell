$servers = @()
#$servers += "SQLINTRA"
#$servers += "ASHBI-QA1"
#$servers += "ACNSQL"
#$servers += "EDI-2008"
#$servers += "TRITON-SQL"
#$servers += "ASH-EDIREPORTS"
#$servers += "SQL-REPORTS08"
#$servers += "SQLCRM"
#$servers += "ASHB-SQL"
#$servers += "ASH-DWREPORTS"
#$servers += "ASH-STGSQLCMS"
#$servers += "HYRSQL"
#$servers += "ASHSQL-DWBI"
#$servers += "IN1-EDI"
#$servers += "SD-VCSQL1"
#$servers += "SD-D-PROVSCHSQL"
#$servers += "SD-S-PROVSCHSQL"
#$servers += "SQL-reports08"
#$servers += "SQLCRM"
#$servers += "V4NET-SAN"
#$servers += "SD-ESPSQL"
#$servers += "ASH-XENDOCSQL"
$servers += "ASHCMS"

$data2 = $servers | 
    Get-DbaDiskSpace | 
    Where-Object {$_.SizeInGB -gt 0 -and ($_.FreeInGB -lt 2 -or $_.PercentFree -lt 5)} 

$data2 | Format-Table

Foreach ($server in $data2) {
    #$server
    Get-DbaDatabaseFreespace $server.Server | 
        Where-Object {$_.PhysicalName -like "$($server.Name)*"} |
        Where-Object {$_.FileSizeMB -gt 5120} | 
        Where-Object {$_.PercentUsed -lt 90} | 
        Sort-Object FreeSpaceMB -Descending |
        Format-Table    #sqlserver, DatabaseName, UsedSpaceMB, FreeSpaceMB, FileSizeMB
        #Where-Object {$_.PercentUsed -lt 90} |
        #Where-Object {$_.FileSizeMB -gt 5120} |        
}
<#
$servername = "SQL-REPORTS08"
$database = "V4_SPPS_V6"
$sqlserver = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $servername
$db = $sqlserver.databases[$database]

$db.refresh()
$file = $db.LogFiles['V4_SPPS_V6_log']
$file |
    select *

$file.growth = 1048576
$file.shrink(1024)
$file.alter()
$file.refresh()
#>

#Expand-SqlTLogResponsibly -SqlServer $servername -database $database -TargetLogSizeMB 20480 -verbose -whatif


#Expand-SqlTLogResponsibly -SqlServer "sd-d-provschsql" -databases "promis" -TargetLogSizeMB 1024 -verbose -WhatIf