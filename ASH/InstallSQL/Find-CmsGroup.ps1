    function Find-CmsGroup {
        [OutputType([object[]])]
        [cmdletbinding()]
        param(
            $CmsGrp,
            $Base = $null,
            $Stopat
        )
        $results = @()
        foreach ($el in $CmsGrp) {
            if ($null -eq $Base -or [string]::IsNullOrWhiteSpace($Base) ) {
                $partial = $el.name
            }
            else {
                $partial = "$Base\$($el.name)"
            }
            if ($partial -eq $Stopat) {
                return $el
            }
            else {
                foreach ($elg in $el.ServerGroups) {
                    $results += Find-CmsGroup -CmsGrp $elg -Base $partial -Stopat $Stopat
                }
            }
        }
        return $results
    }