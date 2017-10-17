. "\\tog-sql\sog\apps\microsoft\sql server\PowerShell\Scripts\Functions\script-job.ps1"

function Script-JobsByCategory {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [string]$server,    
        [string]$category,
        [string]$path
    )
    process
    {
        $jobserver = New-Object Microsoft.SqlServer.Management.SMO.Server($server)

        $jobserver.JobServer.Jobs |
            Where-Object {$_.Category -eq "$category"} |
            Script-Job -path $path -server $server -verbose:$VerbosePreference -whatif:$([bool]$WhatIfPreference.IsPresent)
    }
}