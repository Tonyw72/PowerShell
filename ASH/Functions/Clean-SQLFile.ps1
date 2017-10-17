Function Clean-SQLFile {
    [OutputType([object[]])]
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)][string] $FileName
    )

    $chk = Test-Path $FileName
    if (-not $chk) {
        Write-Error "File doesn't exist"
        break
    }

    $script = @()
    [string]$scriptpart =""

    $fullscript = Get-Content $FileName

    foreach($line in $fullscript)
    {   
        if ($line.Trim() -eq "") {}
        elseif ($line.trim() -ne "GO")
        {       
            Write-Verbose $line   
            $scriptpart += $line + "`n"
        }
        else
        {
            $properties = @{Scriptpart = $scriptpart}
            $newscript = New-Object PSObject -Property $properties
            $script += $newscript
            $scriptpart = ""
            $newscrpt = $null
            Write-Verbose "------"
        }
    }

    return $script
}
