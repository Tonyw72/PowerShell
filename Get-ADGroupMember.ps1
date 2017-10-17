Get-ADGroupMember -identity "Domain Admins" -Recursive | foreach{ get-aduser $_} | select SamAccountName,objectclass,name


$user = get-aduser -filter {aAMAccountname -eq corp\anthonyw}
$user

if (dsquery user -samid 'anthonyw') {"test"}