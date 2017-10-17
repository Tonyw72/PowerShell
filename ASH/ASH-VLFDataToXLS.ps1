function ASH-VLFDataToXLS {
    [cmdletbinding()]
    param ( 
        [String] $CMSServerName = "TOG-SQL",
        [String[]] $ServerGroups,
        [String[]] $ServerList,
        [switch]$ToGrid,
        [switch]$ToTable,
        [string] $OutputPath = "",
        [int] $TooManyVLF = 25,
        [int] $WayTooManyVLF = 50,
        [string] $savePath,
        [switch] $ShowXLS
          
    )    
    <#
    . "\\tog-sql\SOG\Apps\Microsoft\SQL Server\Powershell\Scripts\get-serverlist.ps1"
        
    $connectionString = "data source=$CMSServerName;initial catalog=master;integrated security=sspi;" 
    $sqlConnection = New-Object ("System.Data.SqlClient.SqlConnection") $connectionstring 
    $conn = New-Object ("Microsoft.SQLServer.Management.common.serverconnection") $sqlconnection 
    $cmsStore = New-Object ("Microsoft.SqlServer.Management.RegisteredServers.RegisteredServersStore") $conn 
    $cmsRootGroup = $cmsStore.ServerGroups["DatabaseEngineServerGroup"].ServerGroups       
    
    # Get the servers from the CMS Groups
    foreach ($group in $ServerGroups) {        
        Get-ServerList -cmsName $CMSServerName -serverGroup $group -recurse | foreach -process { $ServerList += $_.servername}
    }
    #>
    # no serverlist or group passed in, so process the whole CMS
    if ($ServerList.Count -eq 0) {
        #$cmsRootGroup.RegisteredServers | Sort-Object -property servername -unique | foreach -process { $ServerList += $_.servername}    
        #Get-ServerList -cmsName $CMSServerName -recurse | foreach -process { $ServerList += $_.servername} 
        $ServerList += Get-DbaRegisteredServerName -SqlServer "$CMSServerName" | 
            select -ExpandProperty Name |
            Sort-Object -Unique
    }

    if ($ServerList.Count -eq 0) {
        Write-Output "No servers to process"
        break;
    }

    #$ServerList | Format-Table -AutoSize
    $serverlist = $serverlist | Sort-Object -unique
    
    # Create a .com object for Excel
    $xl = new-object -comobject excel.application

    $xl.Visible = $ShowXLS # Set this to False when you run in production

    $wb = $xl.Workbooks.Add() # Add a workbook
    $ws = $wb.Worksheets.Item(1) # Add a worksheet 
    $cells=$ws.Cells
    $Row = 2
    $Col = 1
    $Date = Get-Date
    $Title = 'Results of Script to show VLFs and File Growth run on ' + $Date
    $cells.item(2,1)="Server"
    $cells.item(2,1).font.size=16
    $cells.item(2,2)="Database"
    $cells.item(2,2).font.size=16
    $cells.item(2,3)="No. of VLFs"
    $cells.item(2,3).font.size=16
    $cells.item(2,4)="Growth"
    $cells.item(2,4).font.size=16
    $cells.item(2,5)="Growth Type"
    $cells.item(2,5).font.size=16
    $cells.item(2,6)="Size"
    $cells.item(2,6).font.size=16
    $cells.item(2,7)="Used Space"
    $cells.item(2,7).font.size=16
    $cells.item(2,8)="Name"
    $cells.item(2,8).font.size=16
    $cells.item(2,9)="File Name"
    $cells.item(2,9).font.size=16

    foreach ($ServerName in $ServerList) {
        Write-Verbose "Checking $($ServerName)"
        $srv = New-Object Microsoft.SqlServer.Management.Smo.Server $ServerName

	    foreach ($db in $srv.Databases|Where-Object {$_.isAccessible -eq $True}) {
            Write-Verbose "`t$($DB.name)"
            $Col = 1
		    $Row++
		    $VLF = $DB.ExecuteWithResults("DBCC LOGINFO").Tables[0].Rows.Count
		    $logFile = $db.LogFiles | Select Growth,GrowthType,Size, UsedSpace,Name,FileName
		    $Name = $DB.name
		    $cells.item($row,$col)=$ServerName
		    $col++
		    $cells.item($row,$col)=$Name
		    $col++
		    if($VLF -gt $TooManyVLF) 
		    {
			    $cells.item($row,$col).Interior.ColorIndex = 6 # Yellow
		    }
		    if($VLF -gt $WayTooManyVLF)
		    {
			    $cells.item($row,$col).Interior.ColorIndex = 3 # Red
		    }
		    $cells.item($row,$col)=$VLF
		    $cells.item($row,$col).HorizontalAlignment = 3 #center
		    $col++
		    $cells.item($row,$col)=$logFile.Growth
		    $cells.item($row,$col).HorizontalAlignment = 4 #right
		    $col++
		    $Type = $logFile.GrowthType.ToString()
		    if($Type -eq 'Percent')
		    {
			    $cells.item($row,$col).Interior.ColorIndex = 3 #Red
		    }
		    $cells.item($row,$col)=$Type
		    $cells.item($row,$col).HorizontalAlignment = 4 #right
		    $col++
		    $cells.item($row,$col)=($logFile.Size)
		    $cells.item($row,$col).HorizontalAlignment = 3 #center
		    $col++
		    $cells.item($row,$col)=($logFile.UsedSpace)
		    $cells.item($row,$col).HorizontalAlignment = 3 #center
		    $col++
		    $cells.item($row,$col)=$logFile.Name
		    $col++
		    $cells.item($row,$col)=$logFile.FileName
	    }
	    #$Row++
    }

    $ws.UsedRange.AutoFilter()
    $ws.UsedRange.EntireColumn.AutoFit()

    $cells.item(1,1)=$Title 
    $cells.item(1,1).font.size=24
    $cells.item(1,1).font.bold=$True
    $cells.item(1,1).font.underline=$True

    if ($savePath -and (Test-Path -Path $savePath)) {
        #$Date = Get-Date -f ddMMyy
        #$filename = "ASH-VLF $(get-date -Format "yyyy-MM-dd HHmmss")"
        $wb.Saveas("$($savePath.TrimEnd('\'))\ASH-VLF $(get-date -Format "yyyy-MM-dd HHmmss").xlsx")
        $wb.close()
    }

    if (-not $ShowXLS) {
        $xl.quit()
        Stop-Process -Name EXCEL
    }
}

<#
cls
ASH-VLFDataToXLS -savePath "\\tog-sql\SOG\Apps\Microsoft\SQL Server\VLF Documentation" -Verbose -ShowXLS
#>
#ASH-VLFDataToXLS  -ShowXLS