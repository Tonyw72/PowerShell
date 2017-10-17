[CmdletBinding(SupportsShouldProcess=$true)]
param()
$servers = @()
$servers += "SD-VNAS01"
$servers += "SD-VNAS02"
$servers += "SD-VNAS03"

$DiskReport = ForEach ($server in $servers)  {
    Write-Verbose "Checking backup shares on $($server)"

    Get-WmiObject win32_logicaldisk <#-Credential $RunAccount#> `
            -ComputerName $server `
            -Filter "DriveType = 3" `
            -ErrorAction SilentlyContinue 
 
    #return only disks with 
    #free space less   
    #than or equal to 0.1 (10%) 
 
    #Where-Object {   ($_.freespace/$_.size) -le '0.1'} 
}
<#
$DiskReport |
    Where-Object {$_.VolumeName -like "*BtoD0*"} |
    sort-object -Property @{Expression = "freespace"; descending =$true} |
    Select-Object @{Label = "Server Name";Expression = {$_.SystemName}},         
        @{Label = "Drive Letter";Expression = {$_.DeviceID}}, 
        @{Label = "Volume Name"; Expression = {$_.VolumeName}}, 
        @{Label = "Total Capacity (GB)";Expression = {"{0:N1}" -f( $_.Size / 1gb)}}, 
        @{Label = "Free Space (GB)";Expression = {"{0:N1}" -f( $_.Freespace / 1gb ) }}, 
        @{Label = 'Free Space (%)'; Expression = {"{0:P0}" -f ($_.freespace/$_.size)}} |
        #Sort-Object -Property @{Expression = "Free Space (GB)"; Descending = $true} |
        Format-Table
        #>

$drive = $DiskReport |
    Where-Object {$_.VolumeName -like "*BtoD0*"} |
    sort-object -Property @{Expression = "freespace"; descending =$true} |
    Select-Object @{Label = "Server Name";Expression = {$_.SystemName}},         
        @{Label = "Drive Letter";Expression = {$_.DeviceID}}, 
        @{Label = "Volume Name"; Expression = {$_.VolumeName}}, 
        @{Label = "Total Capacity (GB)";Expression = {"{0:N1}" -f( $_.Size / 1gb)}}, 
        @{Label = "Free Space (GB)";Expression = {"{0:N1}" -f( $_.Freespace / 1gb ) }}, 
        @{Label = 'Free Space (%)'; Expression = {"{0:P0}" -f ($_.freespace/$_.size)}} |
    #Sort-Object -Property @{Expression = "Free Space (GB)"; Descending = $true} |
    Select-Object -First 1 


Write-Verbose "\\$($drive.'Server Name')\$(($drive.'Volume Name').Split("-")[1].trim()) has $($drive.'Free Space (GB)') GB free" 

"\\$($drive.'Server Name')\$(($drive.'Volume Name').Split("-")[1].trim())"

