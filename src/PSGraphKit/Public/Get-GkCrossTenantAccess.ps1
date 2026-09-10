function Get-GkCrossTenantAccess {
    <#
    .SYNOPSIS
        Report cross-tenant access (B2B) settings: the default policy and any partner overrides.

    .DESCRIPTION
        Reads GET /policies/crossTenantAccessPolicy/default and /partners, and emits one row for the
        default plus one per configured partner, summarizing the inbound trust settings (whether MFA,
        compliant-device, and hybrid-joined claims from the partner are trusted).

        Requires Policy.Read.All. (Full identity-synchronization detail needs a higher role and is
        not surfaced here.)

    .PARAMETER AsReport
        Add a ReportGeneratedUtc column.

    .EXAMPLE
        Get-GkCrossTenantAccess

        The default cross-tenant policy and any partner-specific configurations.

    .EXAMPLE
        Get-GkCrossTenantAccess | Where-Object { $_.Scope -ne 'Default' }

        Only partner-specific overrides.

    .EXAMPLE
        Get-GkCrossTenantAccess -AsReport | Export-Csv .\cross-tenant.csv -NoTypeInformation

    .OUTPUTS
        PSGraphKit.CrossTenantAccess
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.CrossTenantAccess')]
    param(
        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkCrossTenantAccess' -Caller $PSCmdlet | Out-Null
        $now = [datetime]::UtcNow
    }

    process {
        $rows = [System.Collections.Generic.List[object]]::new()

        $default = Invoke-GkGraphRequest -Raw -Uri '/policies/crossTenantAccessPolicy/default' -CallerFunction 'Get-GkCrossTenantAccess'
        if ($default) { $rows.Add(@{ Item = $default; Scope = 'Default'; IsServiceDefault = [bool](Get-GkDictValue $default 'isServiceDefault') }) }

        foreach ($p in (Invoke-GkGraphRequest -Uri '/policies/crossTenantAccessPolicy/partners' -CallerFunction 'Get-GkCrossTenantAccess')) {
            $rows.Add(@{ Item = $p; Scope = [string](Get-GkDictValue $p 'tenantId'); IsServiceDefault = $null })
        }

        foreach ($r in $rows) {
            $trust = Get-GkDictValue $r.Item 'inboundTrust'
            $obj = [ordered]@{
                PSTypeName                  = 'PSGraphKit.CrossTenantAccess'
                Scope                       = $r.Scope
                IsServiceDefault            = $r.IsServiceDefault
                TrustMfa                    = [bool](Get-GkDictValue $trust 'isMfaAccepted')
                TrustCompliantDevice        = [bool](Get-GkDictValue $trust 'isCompliantDeviceAccepted')
                TrustHybridJoinedDevice     = [bool](Get-GkDictValue $trust 'isHybridAzureADJoinedDeviceAccepted')
                Id                          = [string](Get-GkDictValue $r.Item 'tenantId')
            }
            if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
            [pscustomobject]$obj
        }
    }
}
