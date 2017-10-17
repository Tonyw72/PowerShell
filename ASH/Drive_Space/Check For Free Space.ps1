$servers = @()
#$servers += "SQLINTRA"
#$servers += "ASHBI-QA1"
#$servers += "ACNSQL"
#$servers += "EDI-2008"
#$servers += "triton-sql"
#$servers += "ASH-EDIREPORTS"
#$servers += "SQl-reports08"
#$servers += "SQLCRM"
#$servers += "ASHB-SQL"
#$servers += "ash-dwreports"
#$servers += "ASH-STGSQLCMS"
#$servers += "HYRSQL"
#$servers += "ASHSQL-DWBI"
#$servers += "IN1-EDI"
$servers += "edi-2008"

$data2 = $servers | 
    Get-DbaDiskSpace | 
    Where-Object {$_.SizeInGB -gt 0 -and ($_.FreeInGB -lt 2 -or $_.PercentFree -lt 5)} 

$data2 | ft

Foreach ($server in $data2) {
    #$server
    Get-DbaDatabaseFreespace $server.Server | 
        Where-Object {$_.PhysicalName -like "$($server.Name)*"} |
        Sort-Object FreeSpaceMB -Descending |
        ft #sqlserver, DatabaseName, UsedSpaceMB, FreeSpaceMB, FileSizeMB
        #Where-Object {$_.PercentUsed -lt 90} |
        #Where-Object {$_.FileSizeMB -gt 5120} |        
}