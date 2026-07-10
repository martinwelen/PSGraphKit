function Get-GkRiskDetection {
    <#
    .SYNOPSIS
        Report Microsoft Entra ID Protection risk detections (e.g. impossible travel, leaked
        credentials, anonymous IP).

    .DESCRIPTION
        Reads GET /identityProtection/riskDetections. Requires the IdentityRiskEvent.Read.All scope
        and a Microsoft Entra ID P1 or P2 license (P2 gives full detail). When unavailable, warns and
        returns nothing.

    .PARAMETER RiskLevel
        Filter to a single risk level: low, medium, or high.

    .PARAMETER First
        Return at most N risk detections, stopping pagination early. Use to bound the pull on a large
        tenant instead of paging the entire riskDetections collection.

    .PARAMETER AsReport
        Add a ReportGeneratedUtc column.

    .EXAMPLE
        Get-GkRiskDetection | Sort-Object DetectedDateTime -Descending | Select-Object -First 20

        The 20 most recent risk detections.

    .EXAMPLE
        Get-GkRiskDetection -RiskLevel high | Group-Object RiskEventType

        High-risk detections grouped by type.

    .EXAMPLE
        Get-GkRiskDetection -AsReport | Export-Csv .\risk-detections.csv -NoTypeInformation

    .OUTPUTS
        PSGraphKit.RiskDetection
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.RiskDetection')]
    param(
        [ValidateSet('low', 'medium', 'high')]
        [string] $RiskLevel,

        [ValidateRange(1, 500000)]
        [int] $First,

        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkRiskDetection' | Out-Null
        $now = [datetime]::UtcNow
    }

    process {
        try {
            $detections = Invoke-GkGraphRequest -Uri '/identityProtection/riskDetections' -MaxResult $First -CallerFunction 'Get-GkRiskDetection'
        }
        catch {
            Write-Warning "Could not read risk detections. This report requires a Microsoft Entra ID P1/P2 license and IdentityRiskEvent.Read.All. $($_.Exception.Message)"
            return
        }

        foreach ($d in $detections) {
            $level = [string](Get-GkDictValue $d 'riskLevel')
            if ($RiskLevel -and $level -ne $RiskLevel) { continue }

            $obj = [ordered]@{
                PSTypeName        = 'PSGraphKit.RiskDetection'
                DetectedDateTime  = ConvertTo-GkDateTime (Get-GkDictValue $d 'detectedDateTime')
                UserPrincipalName = [string](Get-GkDictValue $d 'userPrincipalName')
                RiskEventType     = [string](Get-GkDictValue $d 'riskEventType')
                RiskLevel         = $level
                RiskState         = [string](Get-GkDictValue $d 'riskState')
                DetectionTiming   = [string](Get-GkDictValue $d 'detectionTimingType')
                IpAddress         = [string](Get-GkDictValue $d 'ipAddress')
                Id                = [string](Get-GkDictValue $d 'id')
            }
            if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
            [pscustomobject]$obj
        }
    }
}
