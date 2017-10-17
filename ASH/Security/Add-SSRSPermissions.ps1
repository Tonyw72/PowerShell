function Add-SSRSPermissions {
    <#
    .SYNOPSIS
        This function will assign permissions to SQL Server Reporting Services reports and folders. 
    .DESCRIPTION
        This function will assign permissions to SQL Server Reporting Services reports and folders. 
        If the requested url inherits it's permissions, the script will walk up the tree until if finds the first parent object that's not inheriting it's permissions
    .EXAMPLE
        Add-SSRSPermissions -ReportServer stg-desktop -url 'http://stg-desktop/Reports/Pages/Folder.aspx?ItemPath=%2fFinance+Reports' -GroupUserNames "CORP\ChrisH" -RoleNames "Browser", "Content Manager" 

        Adds CORP\ChrisH to the Browser and Content Manager roles for the Finance Reports folder on stg-desktop

    .EXAMPLE 
    
        Add-SSRSPermissions `
            -ReportServerUri "http://stg-desktop/reportserver/ReportService2010.asmx?wsdl" `
            -url "http://stg-desktop/Reports/Pages/Report.aspx?ItemPath=%2fFitness+Reports%2fUtilization%2fTest_DV_Sep10_Fitness+Member+Utilization+DW+Medica+MN+SF" `
            -GroupUserNames ("CORP\Anthonyw") `
            -RoleNames ("Browser", "My Reports") `
            -Verbose -WhatIf
    .INPUTS
        ReportServer - Select the reports server being used from the autocomplete

        URL (string) - The url needing the permissions

        GroupUserNames (string array) - An array of the users to be granted the requested permissions
        
        RoleNames (string array) - An array of which permissions being requested

    .PARAMETER ReportServer    
        Select the Report Server
    .PARAMETER URL        
        URL that permissions are requested for
    .PARAMETER GroupUserNames
        Array of Active Directory Groups or Users
    .PARAMETER RoleNames
        Array of SSRS roles
    .OUTPUTS
        No outputs
    .NOTES
        Created by Tony Wilhelm 2017-09-14
    .COMPONENT

    .FUNCTIONALITY
        
    #>
    [cmdletbinding(SupportsShouldProcess=$true)]
    param ( 
        [validateSet("stg-desktop", "stg-desktop:8090", "tfs12-sqlbld", "SD-P-SSRS", "SD-D-SSRS", "SD-S-SSRS")]
        [Parameter(Mandatory=$true)][string] $ReportServer,        
        [Parameter(Mandatory=$true)][string] $URL,
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)][String[]] $GroupUserNames,
        [Parameter(Mandatory=$true)][string[]] $RoleNames
    )
    begin {
        # Executes once before first item in pipeline is processed
        $InheritParent = $true
        
        $ReportServerUri = "http://$($ReportServer)/reportserver/ReportService2010.asmx?wsdl"

        # Connect to the Report server
        Write-Verbose "Connecting to the SSRS web service ($($ReportServerUri))"
        $rsProxy = New-WebServiceProxy -Uri $ReportServerUri -UseDefaultCredential

        $type = $rsProxy.GetType().Namespace;
        $policyType = "{0}.Policy" -f $type;
        $roleType = "{0}.Role" -f $type;

        # Get the report path
        $URL = $URL.Replace("%2f", "/").Replace("+", " ")
        $path = [System.Web.HttpUtility]::ParseQueryString(([system.uri]$URL).Query)['itempath']

        do { 
            $Policies = $rsProxy.GetPolicies($path , [ref] $InheritParent)

            Write-Verbose "Checking for inheritence on $($path) = $($InheritParent)"

            if ($InheritParent -eq $false) {break}
                
            if ($path.LastIndexOf("/") -eq 0 ) {
                $path = "/"
            }
            else {
                $path = $path.Substring(0,$path.LastIndexOf("/"))
            }
        } while ($path -ne "/")

        Write-Verbose "Setting permissions on $($path)"

    }
    process {        
        # Executes once for each pipeline object
        foreach ($GroupUserName in $groupusernames) {
            
            #Return all policies that contain the user/group we want to add
            $Policy = $Policies | 
	            Where-Object { $_.GroupUserName -eq $GroupUserName } | 
	            Select-Object -First 1
                
            if (-not $Policy) {
                Write-Verbose "`t $($GroupUserName) No policy for this user - creating a new one"
	            $Policy = New-Object ($policyType)
	            $Policy.GroupUserName = $GroupUserName
	            $Policy.Roles = @()
	            #Add new policy to the folder's policies
	            $Policies += $Policy
            }
            else {
                Write-Verbose "`t $($GroupUserName)"
            }
                
            foreach ($RoleName in $RoleNames) {

                #Add the role to the new Policy
                $r = $Policy.Roles |
                Where-Object { $_.Name -eq $RoleName } |
                Select-Object -First 1

                if (-not $r) 
                {
                    Write-Verbose "`t`t $($RoleName)"    
	                $r = New-Object ($roleType)
	                $r.Name = $RoleName
	                $Policy.Roles += $r
                }
            }
            
            if($PSCmdlet.ShouldProcess($GroupUserName, "granting permissions")) {
                $rsProxy.setpolicies($path, $Policies);
            }
        }
    }

    End {
        # Executes once after last pipeline object is processed
      }
}

<#

#>