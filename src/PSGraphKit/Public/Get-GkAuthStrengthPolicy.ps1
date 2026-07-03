function Get-GkAuthStrengthPolicy {
    <#
    .SYNOPSIS
        Report authentication strength policies (built-in and custom) and their allowed method
        combinations.

    .DESCRIPTION
        Reads GET /policies/authenticationStrengthPolicies, which back the "require authentication
        strength" grant control in Conditional Access. Shows each policy's type and the method
        combinations it accepts (e.g. fido2, x509CertificateMultiFactor) — useful for confirming a
        phishing-resistant option is defined for privileged access.

        Requires Policy.Read.AuthenticationMethod (or Policy.Read.All).

    .PARAMETER CustomOnly
        Return only custom (tenant-defined) policies.

    .PARAMETER AsReport
        Flatten AllowedCombinations to a '; '-joined string and add ReportGeneratedUtc.

    .EXAMPLE
        Get-GkAuthStrengthPolicy

        All authentication strength policies with their allowed combinations.

    .EXAMPLE
        Get-GkAuthStrengthPolicy -CustomOnly

        Only custom strengths the tenant has defined.

    .EXAMPLE
        Get-GkAuthStrengthPolicy -AsReport | Export-Csv .\auth-strengths.csv -NoTypeInformation

    .OUTPUTS
        PSGraphKit.AuthStrengthPolicy
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.AuthStrengthPolicy')]
    param(
        [switch] $CustomOnly,
        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkAuthStrengthPolicy' | Out-Null
        $now = [datetime]::UtcNow
    }

    process {
        $policies = Invoke-GkGraphRequest -Uri '/policies/authenticationStrengthPolicies' -CallerFunction 'Get-GkAuthStrengthPolicy'

        foreach ($p in $policies) {
            $type = [string](Get-GkDictValue $p 'policyType')
            if ($CustomOnly -and $type -ne 'custom') { continue }

            $combos = @(Get-GkDictValue $p 'allowedCombinations')
            $obj = [ordered]@{
                PSTypeName          = 'PSGraphKit.AuthStrengthPolicy'
                DisplayName         = [string](Get-GkDictValue $p 'displayName')
                PolicyType          = $type
                AllowedCombinations = if ($AsReport) { $combos -join '; ' } else { $combos }
                CombinationCount    = $combos.Count
                Modified            = ConvertTo-GkDateTime (Get-GkDictValue $p 'modifiedDateTime')
                Id                  = [string](Get-GkDictValue $p 'id')
            }
            if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
            [pscustomobject]$obj
        }
    }
}
