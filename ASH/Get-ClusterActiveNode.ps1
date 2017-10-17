function Get-ClusterActiveNode
{
 Param(
	[Parameter(
		Position=0, 
	        Mandatory=$true, 
        	ValueFromPipeline=$true,
	        ValueFromPipelineByPropertyName=$true)]
        	[string]$strIntanceFQDN
    )
    # IP?
    if(!($strIntanceFQDN -match "\d+\.\d+\.\d+\.\d+"))
    {
        $arrIntance = $strIntanceFQDN.Split('.')
        $strInstance = $arrIntance[0]
    }
 
    # translate IP to Hostname
    else
    {
        $result = [System.Net.Dns]::gethostentry($strIntanceFQDN) | select HostName
        $ServerFQDN = $result.hostname
        $arrIntance = $ServerFQDN.Split('.')
        $strInstance = $arrIntance[0]
    }
 
    # does not work otherwise
    $ErrorActionPreference = "SilentlyContinue"
    $WmiQuery = Get-WmiObject win32_bios -computername $strIntanceFQDN
    $ErrorActionPreference = "Continue"
 
    # if access with wmi is possible
    if ($WmiQuery)
    {
        $output = gwmi -class "MSCluster_Resource" -namespace "root\mscluster" -computername $strIntanceFQDN  -Authentication PacketPrivacy | where {$_.PrivateProperties.VirtualServerName -match $strInstance -and $_.type -eq "SQL Server"} | `
        Select @{n='SqlInstance';e={$_.PrivateProperties.VirtualServerName}}, `
        @{n='CurrentActiveNode';e={$(gwmi -namespace "root\mscluster" -computerName $strIntanceFQDN -Authentication PacketPrivacy -query "ASSOCIATORS OF {MSCluster_Resource.Name='$($_.Name)'} WHERE AssocClass = MSCluster_NodeToActiveResource" | Select -ExpandProperty Name)}} | select CurrentActiveNode
 
        if (($output.CurrentActiveNode | Measure-Object -Character).Characters -gt 2)
        {
            return $output.CurrentActiveNode 
        }
 
        else
        {
            $output = gwmi -class "MSCluster_Resource" -namespace "root\mscluster" -computername $strIntanceFQDN  -Authentication PacketPrivacy | where {$_.name -match $strInstance} 
            return $output.OwnerNode
        }
    }
 
    # ERROR - no connection to host
    else
    {
        return "N/A"
    }
}