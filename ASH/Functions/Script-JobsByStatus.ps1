. "\\SD-TOG\sog\apps\microsoft\sql server\PowerShell\Scripts\Functions\script-job.ps1"

function Script-JobsByStatus {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [string]$server,    
        [switch]$EnabledOnly,
        [switch]$DisabledOnly,
        [switch]$Delete,
        [string]$path
    )
    process
    {
        $jobserver = New-Object Microsoft.SqlServer.Management.SMO.Server($server)

        if ($DisabledOnly) {
            Write-Verbose "Exporting disabled jobs for $($server)"            
            foreach ($job in $jobserver.JobServer.Jobs | Where-Object {$_.IsEnabled -eq $false}) {
                try {
                    Script-Job -path $path -server $server -Job $job -verbose:$VerbosePreference -whatif:$([bool]$WhatIfPreference.IsPresent)
                    if ($Delete) {   
                        if ($PSCmdlet.ShouldProcess("$($job.name)", "Delete")){
                            #$job.drop()
                        }
                    }
                }
                catch {
                    Write-Error "Error scripting $($job.Name) on $($server)"
                }
            }
        }
        elseif ($EnabledOnly) {
            Write-Verbose "Exporting enabled jobs for $($server)"
            $jobserver.JobServer.Jobs |
                Where-Object {$_.IsEnabled -eq $false} |
                Script-Job -path $path -server $server -verbose:$VerbosePreference -whatif:$([bool]$WhatIfPreference.IsPresent)
        }
        else {
            Write-Verbose "Exporting all jobs for $($server)"
            $jobserver.JobServer.Jobs |
                #Where-Object {$_.IsEnabled -eq $false} |
                Script-Job -path $path -server $server -verbose:$VerbosePreference -whatif:$([bool]$WhatIfPreference.IsPresent)
        }        
    }
}