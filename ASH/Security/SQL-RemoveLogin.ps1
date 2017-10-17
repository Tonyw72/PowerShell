function SQL-DropLogin {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [string]$login,
        [Microsoft.SqlServer.Management.Smo.Server]$server
    )

    process {

        if ($server.logins.contains($login)){
            write-verbose "$($server.name) Dropping $($login)"
            if ($PSCmdlet.ShouldProcess("$($login)", "Dropping")){
                $server.Logins[$login].Drop()
            }
        }
    }
}