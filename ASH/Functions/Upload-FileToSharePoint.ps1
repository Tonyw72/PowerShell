function Upload-FileToSharePoint {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory=$true)][string]$User,
        [validateset("https://ashgroups.sharepoint.com/sites/ITO-TOG")]
        [Parameter(Mandatory=$true)][string]$SiteURL,    
        [validateset("Documents")]    
        [Parameter(Mandatory=$true)][string]$DocLibName,
        [Parameter(Mandatory=$true)][string]$foldername,
        [Parameter(Mandatory=$false)][string]$Folder,
        [parameter(ValueFromPipeline, Mandatory=$false)][string[]]$Files
    )
    begin {
        #Add references to SharePoint client assemblies and authenticate to Office 365 site - required for CSOM
        Write-Verbose "Appending to the path"
        Add-Type -Path "C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\15\ISAPI\Microsoft.SharePoint.Client.dll"
        Add-Type -Path "C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\15\ISAPI\Microsoft.SharePoint.Client.Runtime.dll"

        Write-Verbose "Prompt for the password"
        $Password = Read-Host -Prompt "Please enter your password" -AsSecureString

        #Bind to site collection
        Write-Verbose "Bind to site collection"
        $Context = New-Object Microsoft.SharePoint.Client.ClientContext($SiteURL)
        $Creds = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($User,$Password)
        $Context.Credentials = $Creds

        #Retrieve list
        Write-Verbose "Retrieve list"
        $List = $Context.Web.Lists.GetByTitle($DocLibName)
        $Context.Load($List.RootFolder)
        $Context.ExecuteQuery()

        #$List.RootFolder.ServerRelativeUrl 
        #$files
    }
    process {
        
        $fileList = @()

        foreach ($file in $files) {
            $fileList += (Get-ChildItem $file)
        }


        if ($folder) { $FileList += (dir $folder -file) }

        #$FileList | ft
        
        foreach ($file in $FileList) {
            Write-Verbose "Uploading $($file.fullname)"
            #Write-Verbose $File.FullName

            #[System.IO.File]::ReadAllBytes($File.FullName)

            $FileCreationInfo = New-Object Microsoft.SharePoint.Client.FileCreationInformation
            $FileCreationInfo.Overwrite = $true
            $FileCreationInfo.Content = [System.IO.File]::ReadAllBytes($File.FullName)
            
            $path = $List.RootFolder.ServerRelativeUrl + "/" + $FolderName + "/" + $File.Name            
            $FileCreationInfo.URL = $path            
            $UploadFile = $List.RootFolder.Files.Add($FileCreationInfo)
            
            $Context.Load($UploadFile)
            $Context.ExecuteQuery() > $null

            #$UploadFile.ListItemAllFields | ft

            $item = $UploadFile.ListItemAllFields
            $item["Created"] = $file.CreationTime
            $item["Modified"]= $file.modifiedTime
            $item.Update()

        }        
    }
}