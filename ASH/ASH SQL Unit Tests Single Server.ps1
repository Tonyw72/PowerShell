. "\\sd-tog\SOG\Apps\Microsoft\SQL Server\Powershell\Scripts\Functions\Send-EmailHTML.ps1"

cls
$StartTime = get-date

$Path = '\\sd-tog\SOG\Apps\Microsoft\SQL Server\Powershell\Scripts\Pester\Test-SQLDefaults.ps1'
$tests = @()


$SQLServers = @()
#$SQLServers += "TESTASHLINKSQL"
#$SQLServers += "tog-sql"
#$SQLServers += "SD-D-MICCSQL"
#$SQLServers += "SD-D-ProvSCHSQL"
#$SQLServers += "SD-S-ProvSCHSQL"
#$SQLServers += "IN-DR-ProvSCHSQL"
#$SQLServers += "ASH-CRMSQLDEVSTG"
#$SQLServers += "acnsql"
#$SQLServers += "SD-P-ASHLNKSQL1"
#$SQLServers += "SD-P-ASHLNKSQL2"
#$SQLServers += "IN-P-ASHLNKSQL3"
#$SQLServers += "SD-P-FINSQL1"
#$SQLServers += "SD-P-NOCSQL"
#$SQLServers += "SD-P-SSRS"
#$SQLServers += "SD-D-SSRS"
$SQLServers += "SD-Q-FitnessSQL"

$Date = Get-Date -Format MM-dd-yyyy_hhmmss

foreach($Server in $SQLServers | sort -Unique)
{
    $Script = @{
        Path = $Path;
        Parameters = @{ 
            Servers = $Server; 
            SQLAdmins = 'CORP\Domain Admins';
            DataDirectory = 'J:\SQLServer\Data';
            LogDirectory = 'K:\SQLServer\Log';
            OlaSysFullFrequency = 'Daily';
            OlaSysFullStartTime = '21:00:00'; 
            OlaSysFullRetention = 192;           
            OlaUserFullSchedule = 'Weekly';
            OlaUserFullFrequency = 1; ## 1 for Sunday
            OlaUserFullStartTime = '22:00:00';
            OlaUserFullRetention = 192;
            OlaUserDiffSchedule = 'Weekly';
            OlaUserDiffFrequency = 126; ## 126 for every day except Sunday
            OlaUserDiffStartTime = '22:00:00';
            OlaUserDiffRetention = 192;
            OlaUserLogSubDayInterval = 5;
            OlaUserLoginterval = 'Minute';
            OlaUserLogRetention = 192;
            MaximumHistoryRows = 50000;
            MaximumJobHistoryRows = 1000;
            DefaultFillFactor = 85            
        }
    }    
    $tempFolder = 'D:\SQLReports\'
    $InstanceName = $Server.Replace('\','-')
    $File = "$($tempFolder)$($Date)\$($InstanceName)"

    New-Item -ItemType Directory -Force -Path "$($tempFolder)$($Date)\" | Out-Null
    #$File = $tempFolder + get-date -Format "yyyy-MM-dd_HHmmss" + $InstanceName 
    
    $XML = $File + '.xml'
    
    $tests += Invoke-Pester -Script $Script -OutputFile $xml -OutputFormat NUnitXml -PassThru
}
Push-Location $tempFolder
#download and extract ReportUnit.exe

$url = 'http://relevantcodes.com/Tools/ReportUnit/reportunit-1.2.zip'

$fullPath = Join-Path $tempFolder $url.Split("/")[-1]
$reportunit = $tempFolder + '\reportunit.exe'

if((Test-Path $reportunit) -eq $false) {
    (New-Object Net.WebClient).DownloadFile($url,$fullPath)
    Expand-Archive -Path $fullPath -DestinationPath $tempFolder
}
#run reportunit against report.xml and display result in browser
$HTML = "$($tempFolder)$($Date)\index.html"
& .\reportunit.exe "$($tempFolder)$($Date)\"

ii $HTML

$url = $html.Replace("D:\","\\sd-p-sqlmgt\")

#ii $url

$body = @"
The tests have been updated.<BR>
You can see the latest ones here: $($url)<BR>
<BR>
Servers Tested: $(($tests.TestResult | select describe -Unique).count)<BR>
Tests Passed: $(($tests.testresult | ? {$_.Result -eq "Passed"}).count) <BR>
Tests Failed: $(($tests.testresult | ? {$_.Result -eq "Failed"}).count)<BR>
Tests Skipped: $(($tests.testresult | ? {$_.Result -eq "Skipped"}).count)<BR>
Tests Pending: $(($tests.testresult | ? {$_.Result -eq "Pending"}).count)
"@

$from= "Tony Wilhelm<Anthonyw@ashn.com>"
$to = "tog-dba@ashn.com"
$subject = "ASH SQL Server Unit Testing"
$body = "You can see the latest ones here: $($url)"

Send-MailMessage -from $from -to $to -Subject $subject -Body $body -BodyAsHtml -Verbose #-Attachments $OutFile 

$EndTime = get-date
$RunTime = New-TimeSpan -Start $StartTime -End $EndTime
Write-Output "Process started at: $($StartTime)"
Write-Output "Process ended   at: $($EndTime)"
Write-Output "Run Duration: $("{0:hh}:{0:mm}:{0:ss}" -f $RunTime)"
