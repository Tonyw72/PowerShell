[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$true)][string] $ServerName,
    [Parameter(Mandatory=$false)][string] $Newlocation,
    [Switch] $CopyNotMove   
)
Write-Output "CopyNotMove = $CopyNotMove"

if ($CopyNotMove) {
    Write-Output "Copying the backups for $($ServerName)"
}
else {
    Write-Output "Moving the backups for $($ServerName)"    
}

. "\\sd-tog\SOG\Apps\Microsoft\SQL Server\Powershell\Scripts\Functions\Copy-WithItemProgress.ps1"
#Import-Module SqlServer -verbose:$false -ErrorAction SilentlyContinue > $null
#$server = "stg-hrlreports"
#$ServerName = "testashlinksql"

#get the VNAS share with the most free space
if ($Newlocation -eq "") {
    $newlocation = . "\\Sd-tog\sog\Apps\Microsoft\SQL Server\Powershell\Scripts\cmdlets\Find-EmptyBackupShare.ps1" -verbose
}

$jobs = Get-ChildItem -Path "SQLServer:\sql\$($ServerName)\default\JobServer\Jobs" |
    Where-Object {$_.name -match 'DatabaseBackup - USER_Databases' }

$SourceDir = ""

$jobs | ForEach-Object {
        $jobname = $_.Name
        write-verbose $_.Name 
        #$_.jobsteps.count
        $_.jobsteps | ForEach-Object {
            $items = $_.Command.Split("@")
            $SourceDir = $items[2]
            Write-Verbose "`t Old location: $($items[2])"
            $items[2] = "Directory = N'$($newlocation)',"
            Write-Verbose "`t New location: $($items[2])"
            $_.command = $items -join "@"
            if($PSCmdlet.ShouldProcess("$($servername) - $($jobname)","Changing backup path to: $($newlocation)")){
                $_.alter()  
            }            
        }
    }

#"$($SourceDir.Split("'")[1])\$($ServerName)"

Write-Output "from: $($SourceDir)"
Write-Output "to: $($Newlocation)"

# move the backups to the new location
if($PSCmdlet.ShouldProcess("$($servername)","Moving backup files to: $($newlocation)")) {
    if ($CopyNotMove){
        Copy-WithItemProgress "$($SourceDir.Split("'")[1])\$($ServerName)" "$($newlocation)\$($ServerName)" "/E /Mir /Z /R:5 /MT"
    }
    else{
        Copy-WithItemProgress "$($SourceDir.Split("'")[1])\$($ServerName)" "$($newlocation)\$($ServerName)" "/E /MOVE /Z /R:5 /MT"
    }

}
