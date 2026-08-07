function Get-GkNamedLocation {
    <#
    .SYNOPSIS
        Report Conditional Access named locations (IP ranges and countries).

    .DESCRIPTION
        Reads GET /identity/conditionalAccess/namedLocations, a heterogeneous collection of
        ipNamedLocation (with isTrusted and CIDR ranges) and countryNamedLocation (with a country
        list). Ranges/countries are flattened for reporting.

        Requires Policy.Read.All.

    .PARAMETER TrustedOnly
        Return only trusted IP named locations.

    .PARAMETER AsReport
        Flatten IpRanges/Countries to '; '-joined strings and add ReportGeneratedUtc.

    .EXAMPLE
        Get-GkNamedLocation

        All named locations with their type and ranges/countries.

    .EXAMPLE
        Get-GkNamedLocation -TrustedOnly

        Only trusted IP locations.

    .EXAMPLE
        Get-GkNamedLocation -AsReport | Export-Csv .\named-locations.csv -NoTypeInformation

    .OUTPUTS
        PSGraphKit.NamedLocation
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.NamedLocation')]
    param(
        [switch] $TrustedOnly,
        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkNamedLocation' -Caller $PSCmdlet | Out-Null
        $now = [datetime]::UtcNow
    }

    process {
        $locations = Invoke-GkGraphRequest -Uri '/identity/conditionalAccess/namedLocations' -CallerFunction 'Get-GkNamedLocation'

        foreach ($l in $locations) {
            $odataType = [string](Get-GkDictValue $l '@odata.type')
            $isIp = ($odataType -like '*ipNamedLocation')
            $isTrusted = if ($isIp) { [bool](Get-GkDictValue $l 'isTrusted') } else { $false }

            if ($TrustedOnly -and -not $isTrusted) { continue }

            $ipRanges = @()
            if ($isIp) { $ipRanges = @(Get-GkDictValue $l 'ipRanges' | ForEach-Object { [string](Get-GkDictValue $_ 'cidrAddress') } | Where-Object { $_ }) }
            $countries = if (-not $isIp) { @(Get-GkDictValue $l 'countriesAndRegions') } else { @() }

            $obj = [ordered]@{
                PSTypeName  = 'PSGraphKit.NamedLocation'
                DisplayName = [string](Get-GkDictValue $l 'displayName')
                Type        = if ($isIp) { 'IP' } else { 'Country' }
                IsTrusted   = $isTrusted
                IpRanges    = if ($AsReport) { $ipRanges -join '; ' } else { , $ipRanges }
                Countries   = if ($AsReport) { $countries -join '; ' } else { , $countries }
                Created     = ConvertTo-GkDateTime (Get-GkDictValue $l 'createdDateTime')
                Modified    = ConvertTo-GkDateTime (Get-GkDictValue $l 'modifiedDateTime')
                Id          = [string](Get-GkDictValue $l 'id')
            }
            if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
            [pscustomobject]$obj
        }
    }
}
