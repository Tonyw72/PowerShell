
function ConvertTo-SQLHashString{ 
      param([parameter(Mandatory=$true)] $binhash) 
      $outstring = '0x' 
      $binhash | ForEach-Object {$outstring += ('{0:X}' -f $_).PadLeft(2, '0')} 
      return $outstring 
} 


# thanks to MIke Fal
#http://www.mikefal.net/2015/02/17/copying-sql-logins-with-powershell/

$srv = New-Object ('Microsoft.SqlServer.Management.Smo.Server') "hyrsql"
$srvDR = New-Object ('Microsoft.SqlServer.Management.Smo.Server') "hyrsql-dr"

 
#Make sure we script out the SID 


$so = new-object microsoft.sqlserver.management.smo.scriptingoptions 
$so.LoginSid = $true 

$i=0

foreach ($login in $srv.Logins) {

    Write-Progress -Activity "Processing $($login.name)" -PercentComplete ($i/$srv.Logins.Count*100)

    if ($srvdr.logins.Contains($login.Name) -ne $true) {           

        #"$($login.name) - $($login.IsDisabled)"
        #$login.Script()
        $lscript = $login.Script($so) | Where {$_ -notlike 'ALTER LOGIN*DISABLE'}
        
        if($login.LoginType -eq 'SqlLogin'){
        
            $sql = "SELECT convert(varbinary(256),[password_hash]) as hashedpass FROM sys.sql_logins where name='"+$login.name+"'" 
            #$sql
            $hashedpass = ($srv.databases['tempdb'].ExecuteWithResults($sql)).Tables.hashedpass 
            #$hashedpass 
            $passtring = ConvertTo-SQLHashString $hashedpass 

            $rndpw = $lscript.Substring($lscript.IndexOf('PASSWORD'),$lscript.IndexOf(', SID')-$lscript.IndexOf('PASSWORD')) 
            $comment = $lscript.Substring($lscript.IndexOf('/*'),$lscript.IndexOf('*/')-$lscript.IndexOf('/*')+2) 
            $lscript = $lscript.Replace($comment,'') 
            $lscript = $lscript.Replace($rndpw,"PASSWORD = $passtring HASHED") 
        }
        else {
            $username = $login.name.split('\')[1]
            #$username 
            
            #$user = get-aduser -filter {UserPrincipalName -eq $username}
            #$user
            #(dsquery user -samid $username)

            if ((dsquery user -samid $username) -eq $null) {            
                continue
            }
            
        }
        $lscript
    }

    $i += 1

}
