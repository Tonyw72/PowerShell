$servers = Get-SqlRegisteredServerName -SqlServer "tog-SQl" | Sort-Object -Unique 

$data = $servers | Test-DbaMaxDop -Detailed -Verbose

$from= "Anthonyw@ashn.com"
$to = "Anthonyw@ashn.com"
$cc = "tog-dba@ashn.com"
$bcc = "servicedesk@ashn.com"
$subject = "Updating the MAXDOP on SQL Servers"

$smtp = New-Object net.mail.smtpclient("Relay.corp.ashn.com")
$message = New-Object System.Net.Mail.MailMessage $from, $to

$message.cc.add($cc)
$message.bcc.add($bcc)
$message.Subject = $subject
$message.IsBodyHtml = $true

$body = "<h2>Automatically updated the MAXDOP on these servers: </h2>"
$body += "<table><tr><th>Server Name</th>"
$body += "<th>Prev Value</th>"
$body += "<th>New Value</th>"
$body += "<th>NUMA Nodes</th>"
$body += "<th># of Cores</th>"
$body += "</tr>"

foreach ($s in $data | where {$_.CurrentInstanceMaxDop -eq 0} ) {

    $body += "<tr>"
    $body += "<td>$($s.instance)</td>"
    $body += "<td>$($s.CurrentInstanceMaxDop)</td>"
    $body += "<td>$($s.RecommendedMaxDop)</td>"
    $body += "<td>$($s.NUMANodes)</td>"
    $body += "<td>$($s.NumberOfCores)</td>"
    $body += "</tr>"

    Set-DbaMaxDop $s.Instance
}

$body += "</table>"

$message.Body = $body
$smtp.send($message)