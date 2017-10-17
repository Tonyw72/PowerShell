function ASH-CheckDDLTrigger{
    [cmdletbinding(SupportsShouldProcess=$True)]
    param (
        
        [Parameter(Mandatory=$true)][ref]$Server,
        [switch]$AutoFix,
        [Parameter(Mandatory=$true, ValueFromPipeline = $true)]
        [string[]]$Triggers,
        [string]$File
        )
    begin {
        $svr = $Server.value
    }

    Process {
        foreach ($trigger in $Triggers){
            if (-not $svr.Triggers.Contains($Trigger)) {
                Write-Output "$($svr.Name) missing DDL trigger: $($Trigger)"
                if ($AutoFix) {
                    if(Test-Path($File)) {
                        if($PSCmdlet.ShouldProcess($($svr.Name),"Adding DDL Trigger: $($trigger)")) {
                            
                        }
                    }
                    else {Write-Output "File Missing $($File)"}
                }
                else{
                    Write-Verbose "$($svr.Name) has DDL Trigger: $($trigger)"
                }
            }
        }
    }
}