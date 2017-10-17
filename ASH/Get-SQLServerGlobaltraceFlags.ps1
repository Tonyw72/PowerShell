function Get-SQLServerGlobaltraceFlags
{
    [cmdletbinding()]    
    param(
        [parameter(
            Mandatory=$true,
            ValueFromPipeline=$true)]
        [string]$Server
        )  

    process {

        $data = @{"ServerName" = $server
                        ; "TraceFlag" = ""
                        ; "Status" = ""}


        $SQLServer  = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $server
        try {
            $SQLServer.Version | Out-Null

            $TraceFlags = $SQLServer.EnumActiveGlobalTraceFlags() 



            #loop through the trace flags and add the servername in order to create an object with all the required rows to import into a table later
            ForEach($TraceFlag in $TraceFlags) {
                $data = @{"ServerName" = $server
                        ; "TraceFlag" = $TraceFlag.TraceFlag
                        ; "Status" = $TraceFlag.Status}            
                $Output = new-object psobject -Property $data
            }
        }
        catch {
            $data = @{"ServerName" = $server
                        ; "TraceFlag" = ""
                        ; "Status" = "Error Connecting"}                      
        }

        $Output = new-object psobject -Property $data        
        write-output $output
    }
}