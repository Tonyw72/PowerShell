function ASH-SetStartupParameter
{
    [CmdletBinding()]
    param ([parameter(ValueFromPipeline, Mandatory = $true)]
		[Alias("ServerInstance", "SqlInstance")]
		[object[]]$SqlServer,
		[Alias("SqlCredential")]
		[PSCredential]$Credential,
		[string]$TraceFlag
	)
    begin {

        $from= "Anthonyw@ashn.com"
        $to = "Anthonyw@ashn.com"
        $cc = "tog-dba@ashn.com"
        $bcc = "servicedesk@ashn.com"
        $subject = "Setting Startup Parameters on SQL Servers"
        
        $smtp = New-Object net.mail.smtpclient("Relay.corp.ashn.com")
        $message = New-Object System.Net.Mail.MailMessage $from, $to

        $message.cc.add($cc)
        $message.bcc.add($bcc)
        $message.Subject = $subject
        $message.IsBodyHtml = $true

        $body = "<h2>Automatically add the $($TraceFlag) startup parameter to: </h2>"
        $body += "<ul>"
    }

    process
    {

        foreach ($servername in $SqlServer)
		{
			$servercount++
			try
			{
                $instancename = ($servername.Split('\'))[1]
				Write-Verbose "Attempting to connect to $servername"
				
				if ($instancename.Length -eq 0) { $instancename = "MSSQLSERVER" }
				
				$displayname = "SQL Server ($instancename)"

                $CheckData = Get-DbaStartupParameter $servername | select Server, traceflags

                #$CheckData | ft -AutoSize

                
                if ($CheckData.TraceFlags -match $TraceFlag) {
                    Write-Verbose "$($servername) already has $($TraceFlag) set"
                }
                else {
                    $CheckData | ft -AutoSize

                    $srv = New-Object "Microsoft.SqlServer.Management.SMO.Server" $servername;
                    $SQLServerWMI = New-Object "Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer" $srv.ComputerNamePhysicalNetBIOS

                    if($srv.InstanceName -eq "")
                    {
                        $ServiceName = "MSSQLSERVER"
                    }
                    else
                    {
                        $ServiceName = "MSSQL`$$($srv.InstanceName)"
                    }

                    $ServiceName

                    $SQLServerServiceWMI = $SQLServerWMI.Services | Where-Object {$_.name -eq $ServiceName}
                    $SQLServerServiceWMI.StartupParameters 
                    $SQLServerServiceWMI.StartupParameters += ";$($TraceFlag)"
                    $SQLServerServiceWMI.StartupParameters 
                    $SQLServerServiceWMI.Alter()

                    $body += "<li>$($servername)</li>"

                }          				
				
			}
			catch
			{
				Write-Warning "$servername`: $_ "
			}
		}
    }

    end {
        $body += "</ul>"
        $body += "<i> This won't take effect until the service is restarted</i>"

        $body
        
        $message.Body = $body
        $smtp.send($message)
    }
}
