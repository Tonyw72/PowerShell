. "\\SD-tog\sog\apps\microsoft\sql server\powershell\scripts\functions\Remove-InvalidFileNameChars.ps1"

Function Script-Job {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
         [parameter(Mandatory=$true, Position=1, ValueFromPipeline=$false)][string]$path,
         [parameter(Mandatory=$true, Position=2, ValueFromPipeline=$false)][string]$server,
         [parameter(Mandatory=$true, Position=3, ValueFromPipeline=$true)]$Job
    )
    process
    {   
        $nl = [Environment]::NewLine
                
        $newfile = "$($path)\$($server)\$($Job.Name).sql"

        $newfile = Remove-InvalidFileNameChars $newfile

        Write-Verbose "Exporting $($job.name) to $($newfile)"
        
        New-Item $newfile -ItemType file -Force | Out-Null
        
        "USE msdb" + $nl + "GO" + $nl + $nl + $Job.Script() | Out-file $newfile
    }
}