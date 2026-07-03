function Get-GkAdministrativeUnit {
    <#
    .SYNOPSIS
        Report administrative units with membership type, visibility, and member count.

    .DESCRIPTION
        Reads GET /directory/administrativeUnits and, per unit, the member count
        (/administrativeUnits/{id}/members with $count). Dynamic-membership units also show their
        rule.

        Requires AdministrativeUnit.Read.All. Member counting is one call per unit; use
        -SkipMemberCount to omit it.

    .PARAMETER SkipMemberCount
        Do not fetch per-unit member counts (MemberCount will be $null).

    .PARAMETER AsReport
        Add a ReportGeneratedUtc column.

    .EXAMPLE
        Get-GkAdministrativeUnit | Sort-Object MemberCount -Descending

        Administrative units by size.

    .EXAMPLE
        Get-GkAdministrativeUnit | Where-Object MembershipType -eq 'Dynamic'

        Dynamic administrative units (with their rules).

    .EXAMPLE
        Get-GkAdministrativeUnit -SkipMemberCount -AsReport | Export-Csv .\admin-units.csv -NoTypeInformation

    .OUTPUTS
        PSGraphKit.AdministrativeUnit
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.AdministrativeUnit')]
    param(
        [switch] $SkipMemberCount,
        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkAdministrativeUnit' | Out-Null
        $now = [datetime]::UtcNow
    }

    process {
        $units = Invoke-GkGraphRequest -Uri '/directory/administrativeUnits' -CallerFunction 'Get-GkAdministrativeUnit'
        $countFailures = 0

        foreach ($u in $units) {
            $id = [string](Get-GkDictValue $u 'id')

            $memberCount = $null
            if (-not $SkipMemberCount -and $id) {
                try {
                    $resp = Invoke-GkGraphRequest -Raw -CallerFunction 'Get-GkAdministrativeUnit' `
                        -Uri "/directory/administrativeUnits/$id/members?`$count=true&`$top=1" -Headers @{ ConsistencyLevel = 'eventual' }
                    $memberCount = [int](Get-GkDictValue $resp '@odata.count')
                }
                catch { $countFailures++ ; Write-Verbose "PSGraphKit: member count unavailable for AU $id : $($_.Exception.Message)" }
            }

            $rule = [string](Get-GkDictValue $u 'membershipRule')
            $obj = [ordered]@{
                PSTypeName     = 'PSGraphKit.AdministrativeUnit'
                DisplayName    = [string](Get-GkDictValue $u 'displayName')
                MembershipType = if ($rule) { 'Dynamic' } else { 'Assigned' }
                Visibility     = [string](Get-GkDictValue $u 'visibility')
                MemberCount    = $memberCount
                MembershipRule = $rule
                Id             = $id
            }
            if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
            [pscustomobject]$obj
        }

        if ($countFailures -gt 0) {
            Write-Warning "Member count could not be read for $countFailures administrative unit(s)."
        }
    }
}
