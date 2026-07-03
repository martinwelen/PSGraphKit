function Get-GkDomain {
    <#
    .SYNOPSIS
        Report the tenant's domains with verification status and authentication (managed/federated)
        type.

    .DESCRIPTION
        Reads GET /domains. Federated domains are worth flagging in an assessment (external IdP trust).
        Requires the Domain.Read.All scope.

    .PARAMETER FederatedOnly
        Return only federated domains.

    .PARAMETER AsReport
        Flatten SupportedServices to a '; '-joined string and add ReportGeneratedUtc.

    .EXAMPLE
        Get-GkDomain

        All domains with verification and authentication type.

    .EXAMPLE
        Get-GkDomain -FederatedOnly

        Only federated domains.

    .EXAMPLE
        Get-GkDomain -AsReport | Export-Csv .\domains.csv -NoTypeInformation

    .OUTPUTS
        PSGraphKit.Domain
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.Domain')]
    param(
        [switch] $FederatedOnly,
        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkDomain' | Out-Null
        $now = [datetime]::UtcNow
    }

    process {
        $domains = Invoke-GkGraphRequest -Uri '/domains' -CallerFunction 'Get-GkDomain'

        foreach ($d in $domains) {
            $authType = [string](Get-GkDictValue $d 'authenticationType')
            if ($FederatedOnly -and $authType -ne 'Federated') { continue }

            $services = @(Get-GkDictValue $d 'supportedServices')
            $obj = [ordered]@{
                PSTypeName         = 'PSGraphKit.Domain'
                Name               = [string](Get-GkDictValue $d 'id')
                IsVerified         = [bool](Get-GkDictValue $d 'isVerified')
                IsDefault          = [bool](Get-GkDictValue $d 'isDefault')
                AuthenticationType = $authType
                IsAdminManaged     = [bool](Get-GkDictValue $d 'isAdminManaged')
                SupportedServices  = if ($AsReport) { $services -join '; ' } else { $services }
            }
            if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
            [pscustomobject]$obj
        }
    }
}
