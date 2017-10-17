. "\\sd-tog\SOG\apps\microsoft\sql server\powershell\scripts\ola-listjobs.ps1"
. "\\sd-tog\SOG\apps\microsoft\sql server\powershell\scripts\ash-backupcheck.ps1"
. "\\sd-tog\SOG\apps\microsoft\sql server\powershell\scripts\Test-SQLServerGlobaltraceFlags.ps1"
. "\\sd-tog\SOG\Apps\Microsoft\SQL Server\Powershell\Scripts\ASH-VLFDataToXLS.ps1"

ola-ListJobs -OutputPath "\\sd-tog\SOG\Apps\Microsoft\SQL Server\Backup Documentation\Ola Settings"

Get-SqlRegisteredServerName -SqlServer tog-sql | 
    Select -Expandproperty Name |
    Where-Object {$_ -ne "10.8.6.38"} |
    Sort-Object -unique | 
    Test-SQLServerGlobalTraceFlags -flags @("3226", "1118", "8017", "8295", "2371") | 
    export-csv "\\sd-tog\SOG\Apps\Microsoft\SQL Server\Trace Flags\ASH Trace Flags $(get-date -Format "yyyy-MM-dd HHmmss").csv"

<#
ASH-VLFDataToXLS -savePath "\\sd-tog\SOG\Apps\Microsoft\SQL Server\VLF Documentation" -Verbose

ASH-BackupCheck -BackupShares @("\\acnsql-dr\m`$\sqldbbackups") -Verbose -IncludeFileCounts -TestServer:"ACNSQL-DR" `
    -savepath: "\\sd-tog\SOG\Apps\Microsoft\SQL Server\Backup Documentation\acnsql-dr\ASH Backup Status acnsql-dr $(get-date -Format "yyyy-MM-dd HHmmss").xlsx"

ASH-BackupCheck -BackupShares @("\\ASHLINKSQL-dr\m`$\sqldbbackups") -Verbose -IncludeFileCounts -TestServer:"ASHLINKSQL-DR" `
    -savepath: "\\sd-tog\SOG\Apps\Microsoft\SQL Server\Backup Documentation\ASHLINKSQL-dr\ASH Backup Status ASHLINKSQL-dr $(get-date -Format "yyyy-MM-dd HHmmss").xlsx"

ASH-BackupCheck -BackupShares @("\\HYRSQL-dr\m`$\sqldbbackups") -Verbose -IncludeFileCounts -TestServer:"HYRSQL-DR" `
    -savepath: "\\sd-tog\SOG\Apps\Microsoft\SQL Server\Backup Documentation\HYRSQL-dr\ASH Backup Status HYRSQL-dr $(get-date -Format "yyyy-MM-dd HHmmss").xlsx"

ASH-BackupCheck -BackupShares @("\\SQLINTRA-dr\m`$\sqldbbackups") -Verbose -IncludeFileCounts -TestServer:"SQLINTRA-DR" `
    -savepath: "\\sd-tog\SOG\Apps\Microsoft\SQL Server\Backup Documentation\SQLINTRA-dr\ASH Backup Status SQLINTRA-dr $(get-date -Format "yyyy-MM-dd HHmmss").xlsx"

ASH-BackupCheck -BackupShares @("\\in1-vnas01\btod01","\\in1-vnas01\btod02", "\\in1-vnas01\btod03", "\\in1-vnas01\btod04")  -Verbose -IncludeFileCounts `
    -savepath: "\\sd-tog\SOG\Apps\Microsoft\SQL Server\Backup Documentation\in1-vnas01\ASH Backup Status IN1-vnas01 $(get-date -Format "yyyy-MM-dd HHmmss").xlsx"

ASH-BackupCheck -BackupShares @("\\sd-vnas00\btod01","\\sd-vnas00\btod02", "\\sd-vnas00\btod03", "\\sd-vnas00\btod04", "\\sd-vnas00\btod05")  -Verbose -IncludeFileCounts `
    -savepath: "\\sd-tog\SOG\Apps\Microsoft\SQL Server\Backup Documentation\sd-vnas00\ASH Backup Status sd-vnas00 $(get-date -Format "yyyy-MM-dd HHmmss").xlsx"

ASH-BackupCheck -BackupShares @("\\sd-vnas02\btod01","\\sd-vnas02\btod02", "\\sd-vnas02\btod03", "\\sd-vnas02\btod04")  -Verbose -IncludeFileCounts `
    -savepath: "\\sd-tog\SOG\Apps\Microsoft\SQL Server\Backup Documentation\sd-vnas02\ASH Backup Status sd-vnas02 $(get-date -Format "yyyy-MM-dd HHmmss").xlsx"

ASH-BackupCheck -BackupShares @("\\sd-vnas01\btod01","\\sd-vnas01\btod02", "\\sd-vnas01\btod03", "\\sd-vnas01\btod04")  -Verbose -IncludeFileCounts `
    -savepath: "\\sd-tog\SOG\Apps\Microsoft\SQL Server\Backup Documentation\sd-vnas01\ASH Backup Status sd-vnas01 $(get-date -Format "yyyy-MM-dd HHmmss").xlsx"
#>