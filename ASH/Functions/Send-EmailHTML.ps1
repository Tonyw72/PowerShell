function Send-EmailHTML {
<#
.SYNOPSIS
Sends HTML Formatted Email
.DESCRIPTION
Send-EmailHTML will take an array of objects and emails a table in HTML 
.EXAMPLE
$to = "example@mydomain.com"
$from = "PowerShellScript@mydomain.net"
$subject = "List of Running Processes on " + $env:COMPUTERNAME
$smtp = "mySmtpRelay.mydomain.net"
$content = get-process | select processname,id
Send-EmailHTML -To $to -From $from -Subject $subject -SMTPServer $smtp -BodyAsArray $content

DESCRIPTION
-----------
This will email a table of all running processes on the system returned from the Get-Process 
cmdlet.  Using a select statement returns the information with clarity
#>
    [CmdletBinding()] param (
        [parameter(Mandatory=$true)] [string]$To,
        [parameter(Mandatory=$true)] [string]$From,
        [parameter(Mandatory=$true)] [string]$Subject,
        [parameter(Mandatory=$false)] [string]$SMTPServer = $PSEmailServer,
        [parameter(Mandatory=$true)] [array]$BodyAsArray,
        [parameter(Mandatory=$false)] [string]$CC,
        [Parameter(Mandatory=$false)] [string]$BCC
    )
    PROCESS {

        #html style definition
        $htmlHeader = @'
            <style>
                body { background-color:#FFFFFF; } 
                body,table,td,th { font-family:Tahoma; color:Black; Font-Size:10pt } 
                th { font-weight:bold; background-color:#1F497D; color:White } 
                td { background-color:#DDDDDD; }
            </style>
'@
        try {
            #convert array into HTML fragment string
            $htmlContent = $BodyAsArray | ConvertTo-Html -Fragment | Out-String
            
            #initialize mail object
            $mail = new-object System.Net.Mail.MailMessage
            $mail.from = $From
            $mail.to.add($To)
            if ($CC) { 
                $mail.cc.add($CC) 
            }
            if ($BCC) { 
                $mail.bcc.add($BCC) 
            }
            $mail.subject = $Subject
            
            #add html to mail body
            $html = [System.Net.Mail.AlternateView]::CreateAlternateViewFromString( ($htmlHeader + $htmlContent), $null, "text/html" )
            $mail.AlternateViews.Add($html)
            $mail.IsBodyHtml = 1
            
            #send mail
            $smtpClient = new-object System.Net.Mail.SmtpClient
            $smtpClient.Host = $SMTPServer
            $smtpClient.Send($mail)
        }
        catch {
            Write-Host "`n" $_.Exception.Message "`n" -ForegroundColor Magenta
            return
        }
    }    
}