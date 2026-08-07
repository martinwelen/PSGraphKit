function Get-GkSecureScore {
    <#
    .SYNOPSIS
        Report the tenant's latest Microsoft Secure Score, or the per-control breakdown.

    .DESCRIPTION
        Reads GET /security/secureScores and returns the most recent score with the current/max
        values and a computed percentage. With -IncludeControls it instead returns one row per
        control in that score (name, category, score, status) so you can see where points are lost.

        Requires the SecurityEvents.Read.All scope. Secure Score is fed by Microsoft 365 / Defender
        products; no extra Entra license is needed to read it.

    .PARAMETER IncludeControls
        Return the per-control breakdown of the latest score instead of the summary.

    .PARAMETER AsReport
        Add a ReportGeneratedUtc column.

    .EXAMPLE
        Get-GkSecureScore

        The latest overall Secure Score and percentage.

    .EXAMPLE
        Get-GkSecureScore -IncludeControls | Sort-Object Score | Select-Object -First 15

        The 15 controls contributing the fewest points (improvement opportunities).

    .EXAMPLE
        Get-GkSecureScore -AsReport | Export-Csv .\secure-score.csv -NoTypeInformation

    .OUTPUTS
        PSGraphKit.SecureScore or PSGraphKit.SecureScoreControl
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.SecureScore', 'PSGraphKit.SecureScoreControl')]
    param(
        [switch] $IncludeControls,
        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkSecureScore' -Caller $PSCmdlet | Out-Null
        $now = [datetime]::UtcNow
    }

    process {
        # secureScores is returned newest-first and carries a nextLink, so letting Invoke-GkGraphRequest
        # auto-paginate would walk ~90 days of history just to use the latest day. Read only the first
        # page (-Raw returns the untouched first-page body) and take the latest item from it.
        # NB: build $values with a plain if-STATEMENT, not an if-EXPRESSION: an if-expression unrolls a
        # single-element 'value' array back to a scalar, so $values[0] would then index a hashtable and
        # return $null. A direct @() assignment keeps it a real array.
        $body = Invoke-GkGraphRequest -Uri '/security/secureScores?$top=1' -Raw -CallerFunction 'Get-GkSecureScore'
        $values = @()
        if ($body -is [System.Collections.IDictionary]) { $values = @($body['value']) }
        if ($values.Count -eq 0) { Write-Warning 'No Secure Score data was returned for this tenant.'; return }
        $latest = $values[0]

        if ($IncludeControls) {
            foreach ($c in @(Get-GkDictValue $latest 'controlScores')) {
                $obj = [ordered]@{
                    PSTypeName  = 'PSGraphKit.SecureScoreControl'
                    ControlName = [string](Get-GkDictValue $c 'controlName')
                    Category    = [string](Get-GkDictValue $c 'controlCategory')
                    Score       = [double](Get-GkDictValue $c 'score')
                    Description = [string](Get-GkDictValue $c 'description')
                }
                if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
                [pscustomobject]$obj
            }
            return
        }

        $current = [double](Get-GkDictValue $latest 'currentScore')
        $max     = [double](Get-GkDictValue $latest 'maxScore')
        $obj = [ordered]@{
            PSTypeName        = 'PSGraphKit.SecureScore'
            CurrentScore      = $current
            MaxScore          = $max
            Percentage        = if ($max -gt 0) { [math]::Round(($current / $max) * 100, 1) } else { $null }
            ActiveUserCount   = [int](Get-GkDictValue $latest 'activeUserCount')
            LicensedUserCount = [int](Get-GkDictValue $latest 'licensedUserCount')
            ControlCount      = @(Get-GkDictValue $latest 'controlScores').Count
            ScoreDate         = ConvertTo-GkDateTime (Get-GkDictValue $latest 'createdDateTime')
        }
        if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
        [pscustomobject]$obj
    }
}
