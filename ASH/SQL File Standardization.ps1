. "\\tog-sql\SOG\Apps\Microsoft\SQL Server\Powershell\Scripts\Functions\Copy-WithItemProgress.ps1"

$server = "ASHB-DEV"
$DataLoc = "J:\SQLServer\Data"
$LogLoc = "K:\SQLServer\Log"
$ReportPath = "J:\SQLServer\Files_Relocated2.log"
$movedfiles = @()

# Test to make sure the paths exist, and create them if they dont
Invoke-command -ComputerName $server -ScriptBlock { param($path) New-Item -ItemType Directory -Force -Path $path | Out-Null } -ArgumentList (Split-Path $ReportPath)
Invoke-command -ComputerName $server -ScriptBlock { param($path) New-Item -ItemType Directory -Force -Path $path | Out-Null } -ArgumentList $DataLoc
Invoke-command -ComputerName $server -ScriptBlock { param($path) New-Item -ItemType Directory -Force -Path $path | Out-Null } -ArgumentList $LogLoc

#connect to the database
$sqlserver = Connect-DbaSqlServer $server

#$sqlserver.databases
$data = Get-DbaDatabaseFreespace $server

Clear-Host

#$data | ft

$db = $data | 
    Where-Object {-not ($_.FileType -eq "ROWS" -and $_.PhysicalName -like "$($DataLoc)*")} |
    Where-Object {-not ($_.FileType -eq "LOG" -and $_.PhysicalName -like "$($LogLoc)*")} | 
    Where-Object {$_.Database -notlike "ReportServer*"} |
    Where-Object {$_.Filetype -notlike "FULLTEXT"} |
    out-gridview -OutputMode Single 

#region get files to move
$files = Get-DbaDatabaseFreespace $server -databases $db.Database

$datafiles = $files | 
    Where-Object {$_.FileType -eq "ROWS"} |
    Where-Object {$_.PhysicalName -notlike "$($DataLoc)*" }

$logfiles = $files | 
    Where-Object {$_.FileType -eq "LOG"} |
    Where-Object {$_.PhysicalName -notlike "$($LogLoc)*" }
#endregion

Write-Output "Taking database $($db.Database) offline"
$sqlserver.Databases["Master"].ExecuteNonQuery("alter database [$($db.database)] set offline with rollback immediate")

foreach ($Source in $datafiles) {  
    $movedFiles += $source
    $SourceDir = """\\$($server)\$((Split-Path $Source.PhysicalName).replace(":","$"))"""
    $DestDir = """\\$($server)\$($DataLoc.replace(":","$"))"""
    $FileName = """$(Split-Path $Source.PhysicalName -leaf)"""

    $dest = "$($DataLoc)\$(Split-Path $Source.PhysicalName -leaf)"    
    Write-Output "Copying $($Source.PhysicalName) to $($dest)"
    Copy-WithItemProgress $SourceDir $DestDir $FileName "/Z" -Verbose

    $sql = "`tALTER DATABASE [$($db.Database)] MODIFY FILE (NAME = ""$($source.FileName)"", FILENAME= ""$($dest)"")"
    write-output $sql
    $sqlserver.Databases["Master"].ExecuteNonQuery($sql)

    Write-Output "Appending to the list of files moved, to be deleted later"    
  #  Invoke-command -ComputerName $server -ScriptBlock { param($path, $FileName) Add-Content $Path "$($FileName)" } -ArgumentList $ReportPath, $Source.PhysicalName
}

foreach ($Source in $logfiles) {
    $movedFiles += $source
    $SourceDir = """\\$($server)\$((Split-Path $Source.PhysicalName).replace(":","$"))"""
    $DestDir = """\\$($server)\$($LogLoc.replace(":","$"))"""
    $FileName = """$(Split-Path $Source.PhysicalName -leaf)"""

    $dest = "$($logloc)\$(Split-Path $Source.PhysicalName -leaf)"    
    Write-Output "Copying $($Source.PhysicalName) to $($dest)"
    Copy-WithItemProgress $SourceDir $DestDir $FileName "/Z" -Verbose

    $sql = "`tALTER DATABASE [$($db.Database)] MODIFY FILE (NAME = ""$($source.FileName)"", FILENAME= ""$($dest)"")"
    write-output $sql
    $sqlserver.Databases["Master"].ExecuteNonQuery($sql)
   
    Write-Output "Appending to the list of files moved, to be deleted later"    
    Invoke-command -ComputerName $server -ScriptBlock { param($path, $FileName) Add-Content $Path "$($FileName)" } -ArgumentList $ReportPath, $Source.PhysicalName
}  

Write-Output "Bringing database $($db.DatabaseName) online"
$tsql = "alter database [$($db.database)] set online"
Write-Output $tsql
$sqlserver.Databases["Master"].ExecuteNonQuery($tsql)

Write-Output "delete the old files"
foreach ($file in $movedfiles) {
    $message  = 'Delete File'
    $question = "Do you want to delete $($file.PhysicalName)?"

    $choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
    $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
    $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))

    $decision = $Host.UI.PromptForChoice($message, $question, $choices, 1)
    if ($decision -eq 0) {        
        Write-Host 'confirmed'
        Write-Output "`tDeleting file -  $($file.PhysicalName)"
        Invoke-command -ComputerName $server -ScriptBlock { param($FileName) Remove-Item "$($FileName)" } -ArgumentList $file.PhysicalName -Verbose
    } 
    else {
        Write-Host 'cancelled'
    }
}