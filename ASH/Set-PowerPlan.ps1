function Set-PowerPlan {
    [CmdletBinding(SupportsShouldProcess = $True)]
param (
    [ValidateSet("High performance", "Balanced", "Power saver")]
    [ValidateNotNullOrEmpty()]
    [string] $PreferredPlan = "High Performance",

    [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)] 
    [String[]]$ServerNames = $env:COMPUTERNAME 
    )

    Write-Verbose "Setting power plan to `"$PreferredPlan`""

    $guid = (Get-WmiObject -ComputerName $ServerName -Class Win32_PowerPlan -Namespace root\cimv2\power -Filter "ElementName='$PreferredPlan'").InstanceID.ToString()
    $regex = [regex]"{(.*?)}$"
    $plan = $regex.Match($guid).groups[1].value

    powercfg -S $plan

    $Output = "Power plan set to "
    $Output += "`"" + ((Get-WmiObject -ComputerName $ServerName -Class Win32_PowerPlan -Namespace root\cimv2\power -Filter "IsActive='$True'").ElementName) + "`""

    Write-Host $Output
}