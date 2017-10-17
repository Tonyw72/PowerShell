$from= "Anthonyw@ashn.com"
$to = "Anthonyw@ashn.com"
$cc = "tog-dba@ashn.com"
$bcc = "servicedesk@ashn.com"
$subject = "Updating the MaxMemory on SQL Servers"

$smtp = New-Object net.mail.smtpclient("Relay.corp.ashn.com")
$message = New-Object System.Net.Mail.MailMessage $from, $to

$message.cc.add($cc)
$message.bcc.add($bcc)
$message.Subject = $subject
$message.IsBodyHtml = $true

$body = "<h2>Automatically updated the MaxMB on these servers: </h2>"
$body += "<table><tr><th>Server Name</th>"
$body += "<th>Total MB</th>"
$body += "<th>Prev Value</th>"
$body += "<th>New Value</th>"
$body += "</tr>"


$servers = Get-SqlRegisteredServerName -SqlServer "tog-SQl" | Sort-Object -Unique 
$data = $servers | Test-DbaMaxMemory -Verbose

$data | Where-Object {$_.SqlMaxMB -eq 2147483647} |
    ft -AutoSize

$data 


foreach ($s in $data | where {$_.SqlMaxMB -eq 2147483647} ) {
    $body += "<tr>"
    $body += "<td>$($s.Server)</td>"
    $body += "<td>$($s.TotalMB)</td>"
    $body += "<td>$($s.SqlMaxMB)</td>"
    $body += "<td>$($s.RecommendedMB)</td>"
    $body += "</tr>"    

    Set-DbaMaxMemory -SqlServer $s.Server -Verbose
}

$body += "</table>"

$message.Body = $body
$smtp.send($message)