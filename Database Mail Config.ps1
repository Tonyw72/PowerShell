<# 
   .Synopsis 
        This will pull all of the SQL servers from a CMS and output which ones don't have Database Mail configured.
        It will also return the SMTP servers of the ones that are configured in a formatted table, or the Gridview if ran through the ISE

        If you uncomment the line below in the code, it will also change teh SMTP server for ALL of the servers.
        #$Account.MailServers.Item(0).Rename($NewSMTPServer)

   .Example 
    
   .Parameter  

   .Notes 
    NAME: Example- 
    AUTHOR: Tony Wilhelm
    LASTEDIT: 2016-08-30
    KEYWORDS: 
   .Link     
 
 #> 

 . "\\tog-sql\SOG\Apps\Microsoft\SQL Server\Powershell\Scripts\get-serverlist.ps1"
     
    $cmsName = 'TOG-SQL'
    $NewSMTPServer = 'relay.corp.ashn.com'

    # Connect to the SQL CMS Server
    $connectionString = "data source=$cmsName;initial catalog=master;integrated security=sspi;" 
    $sqlConnection = New-Object ("System.Data.SqlClient.SqlConnection") $connectionstring 
    $conn = New-Object ("Microsoft.SQLServer.Management.common.serverconnection") $sqlconnection 
    $cmsStore = New-Object ("Microsoft.SqlServer.Management.RegisteredServers.RegisteredServersStore") $conn 
    $cmsRootGroup = $cmsStore.ServerGroups["DatabaseEngineServerGroup"].ServerGroups
    
    # get a list of all of the unique registered servers on the CMS
    #$servers = $cmsRootGroup.RegisteredServers | Sort-Object -property servername -unique  #| gm
    Get-ServerList -cmsName $cmsName -recurse | foreach -process { $ServerList += $_.servername} 
    $servers = $serverlist | Sort-Object -unique
    
    # Holding variables
    [array]$smtpservers = @()
    $i = 0

    # Loop through the servers
    foreach($svr in $servers) {

        Write-Progress -Activity "Processing $($svr.Servername)" -PercentComplete ($i/$servers.Count*100)
        $i += 1

        #Connect to each server
        $server  = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $svr.Servername   

        # Check to see if database mail is configured
        if ($server.Configuration.DatabaseMailEnabled.ConfigValue -ne 1) {
            Write-Verbose "Database mail not conigured on: $($server.name)"
            $smtpservers += New-Object psobject -Property @{
                            SQLServer = $server.name;
                            NumAccounts = 0;
                            Account = "";
                            SMTPServer = "";
                            Email_Address = "";
                            Display_Name = "";
                            Profile_Name = ""
                            }               

        }
        else {
            # Get the DBMail object
            $MAIL = $server.mail            

            # Loop through the accounts
            foreach ($Account in $MAIL.Accounts) {

                $oldSMTPserver = $Account.MailServers.Item(0).name

                
                foreach ($profile in $Account.GetAccountProfileNames()) {
                    <#
                    Write-Output $profile

                    $sql = @"
                            EXEC msdb.dbo.sp_send_dbmail 
                                @profile_name='$($profile)', 
                                @recipients='anthonyw@ashn.com', 
                                @subject='Test email', 
                                @body='this is only a test'
"@

                    $sql

                    $server.Databases["MASTER"].ExecuteNonQuery("$($sql)")

                    $shell = new-object -comobject "WScript.Shell"
                    $result = $shell.popup("Did you receive a test message from $($Account.DisplayName)?",0,"Question",4+32)
            
                    if ($result -eq 7) {
                        write-output "unable to send email from $($server.name) using $($NewSMTPServer)"

                        return; 
                    }
                    #>

                    # Add the Mail Account & Profile
                    $smtpservers += New-Object psobject -Property @{
                            SQLServer = $server.name;
                            NumAccounts = $MAIL.Accounts.count;
                            Account = $Account.Name;
                            SMTPServer = $Account.MailServers.Item(0).name;
                            Email_Address = $Account.EmailAddress;
                            Display_Name = $Account.DisplayName;
                            Profile_Name = $profile.Name
                            }        

                }
                

                # This will set the name of the SMTPserver to the new value if uncommented
                #$Account.MailServers.Item(0).Rename($NewSMTPServer)                       

            } # foreach ($Account in $MAIL.Accounts)

        }

    } # foreach($svr in $servers) {

    # output the data to a sortable filterable grid 
    $smtpservers | select SQLserver, NumAccounts, Account, SMTPServer, Display_Name, Email_Address, Profile_Name | Out-GridView

    #$smtpservers | select SQLserver, Account, SMTPServer | Format-Table -AutoSize
