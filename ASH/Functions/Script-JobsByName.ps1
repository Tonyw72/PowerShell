. "\\tog-sql\sog\apps\microsoft\sql server\PowerShell\Scripts\Functions\script-job.ps1"

function Script-JobsByName {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
    [string]$server,    
    [string]$name,
    [string]$path
    )
    process
    {
        
        $jobserver = New-Object Microsoft.SqlServer.Management.SMO.Server($server)

        $jobserver.JobServer.Jobs |
            Where-Object {$_.Name -like "$name*"} |
            Script-Job -path $path -server $server  -verbose:$VerbosePreference -whatif:$([bool]$WhatIfPreference.IsPresent)
    }
}