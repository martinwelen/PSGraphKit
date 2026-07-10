function Get-GkRiskyUser {
    <#
    .SYNOPSIS
        Report users flagged by Microsoft Entra ID Protection with their risk level and state.

    .DESCRIPTION
        Reads GET /identityProtection/riskyUsers. Requires a Microsoft Entra ID P2 license and the
        IdentityRiskyUser.Read.All scope. When unavailable (no P2), warns and returns nothing.

    .PARAMETER RiskLevel
        Filter to a single aggregated risk level: low, medium, or high.

    .PARAMETER First
        Return at most N risky users, stopping pagination early. Use to bound the pull on a large
        tenant instead of paging the entire riskyUsers collection.

    .PARAMETER AtRiskOnly
        Return only users whose riskState is atRisk or confirmedCompromised (excludes remediated /
        dismissed).

    .PARAMETER AsReport
        Add a ReportGeneratedUtc column.

    .EXAMPLE
        Get-GkRiskyUser -AtRiskOnly | Sort-Object RiskLevel -Descending

        Users currently at risk, highest first.

    .EXAMPLE
        Get-GkRiskyUser -RiskLevel high

        Only high-risk users.

    .EXAMPLE
        Get-GkRiskyUser -AsReport | Export-Csv .\risky-users.csv -NoTypeInformation

    .OUTPUTS
        PSGraphKit.RiskyUser
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.RiskyUser')]
    param(
        [ValidateSet('low', 'medium', 'high')]
        [string] $RiskLevel,

        [ValidateRange(1, 500000)]
        [int] $First,

        [switch] $AtRiskOnly,

        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkRiskyUser' | Out-Null
        $now = [datetime]::UtcNow
    }

    process {
        try {
            $users = Invoke-GkGraphRequest -Uri '/identityProtection/riskyUsers' -MaxResult $First -CallerFunction 'Get-GkRiskyUser'
        }
        catch {
            Write-Warning "Could not read risky users. This report requires a Microsoft Entra ID P2 license and IdentityRiskyUser.Read.All. $($_.Exception.Message)"
            return
        }

        foreach ($u in $users) {
            $level = [string](Get-GkDictValue $u 'riskLevel')
            $state = [string](Get-GkDictValue $u 'riskState')
            if ($RiskLevel -and $level -ne $RiskLevel) { continue }
            if ($AtRiskOnly -and $state -notin @('atRisk', 'confirmedCompromised')) { continue }

            $obj = [ordered]@{
                PSTypeName        = 'PSGraphKit.RiskyUser'
                UserPrincipalName = [string](Get-GkDictValue $u 'userPrincipalName')
                RiskLevel         = $level
                RiskState         = $state
                RiskDetail        = [string](Get-GkDictValue $u 'riskDetail')
                RiskLastUpdated   = ConvertTo-GkDateTime (Get-GkDictValue $u 'riskLastUpdatedDateTime')
                Id                = [string](Get-GkDictValue $u 'id')
            }
            if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
            [pscustomobject]$obj
        }
    }
}
