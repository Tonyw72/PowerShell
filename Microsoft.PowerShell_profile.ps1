$global:CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
function prompt
{
    $wintitle = $CurrentUser.Name + " " + $Host.Name + " " + $Host.Name
    $host.ui.rawui.WindowTitle = $wintitle
    Write-Host ("PS " + $(get-location) +">") -nonewline -foregroundcolor Magenta 
    return " "
}