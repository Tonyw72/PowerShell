. "\\SD-TOG\SOG\apps\microsoft\sql server\powershell\scripts\ola-listjobs.ps1"
. "\\SD-TOG\SOG\apps\microsoft\sql server\powershell\scripts\ash-backupcheck.ps1"
. "\\SD-TOG\SOG\apps\microsoft\sql server\powershell\scripts\Test-SQLServerGlobaltraceFlags.ps1"
. "\\SD-TOG\SOG\Apps\Microsoft\SQL Server\Powershell\Scripts\ASH-VLFDataToXLS.ps1"

<#
ola-ListJobs -ToGrid -OutputPath "\\tog-sql\SOG\Apps\Microsoft\SQL Server\Backup Documentation\Ola Settings"

Get-SqlRegisteredServerName -SqlServer tog-sql | 
    Sort-Object -unique | 
    Test-SQLServerGlobalTraceFlags -flags @("3226", "1118", "8017", "8295", "2371") | 
    export-csv "\\tog-sql\SOG\Apps\Microsoft\SQL Server\Trace Flags\ASH Trace Flags $(get-date -Format "yyyy-MM-dd HHmmss").csv"
#>

ola-ListJobs -ToGrid 

ASH-VLFDataToXLS -savePath "\\SD-TOG\SOG\Apps\Microsoft\SQL Server\VLF_Documentation" -Verbose