function Test-SQLServerGlobalTraceFlags
{
    [cmdletbinding()]    
    param(
        [parameter(
            Mandatory=$true,
            ValueFromPipeline=$true)]
        [string]$Server,
        [parameter(
            Mandatory=$true)]
        [string[]]$flags
        )  

    process {

        $data = [ordered]@{}

        $data.ServerName = $server

        #$flags = $flags | Sort-Object -unique

        $flags | Sort-Object -unique |ForEach-Object {
            $data.$_ = "0"
            } 
        
        $SQLServer  = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $server
        try {
            $SQLServer.Version | Out-Null

            $TraceFlags = $SQLServer.EnumActiveGlobalTraceFlags() 

            #loop through the trace flags and add the servername in order to create an object with all the required rows to import into a table later
            ForEach($TraceFlag in $TraceFlags) {
                               
                $flag = $TraceFlag.TraceFlag
                                
                if($data.Contains("$($flag)")) {                    
                    $data."$($flag)" = $TraceFlag.Status                    
                }                
            }
        }
        catch {
            #"error"        
        }
        
        $Output = new-object psobject -Property $data        
        write-output $output | Sort-Object
    }
}

<#
$Servers = @()
$Servers += "tog-sql"
$Servers += "ASHBI-PRD1"
$Servers += "ASHBI-PRD2"
$Servers += "STGSQL-ASHLINK8"

$Servers | Test-SQLServerGlobalTraceFlags -flags @("3226", "1118") | ft -AutoSize
#>