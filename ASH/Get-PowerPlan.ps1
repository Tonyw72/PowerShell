Function Get-PowerPlan { 
    param ( 
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)] 
        [String[]]$ServerNames = $env:COMPUTERNAME 
    ) 

    ### function body – see the rest of the code below ### 
    process { 

        foreach ($ServerName in $ServerNames) { 
            try { 
                Get-WmiObject -ComputerName $ServerName -Class Win32_PowerPlan -Namespace "root\cimv2\power" -ErrorAction SilentlyContinue | 
                    Where-Object {$_.IsActive -eq $true} | 
                    Select-Object @{Name = "ServerName"; Expression = {$ServerName}}, @{Name = "PowerPlan"; Expression = {$_.ElementName}} 
            } 

            catch { 
                Write-Error $_.Exception                 
            } 

        } # foreach ($ServerName in $ServerNames) { 

    } # process { 

} 

