function Get-GkConditionalAccessTemplate {
    <#
    .SYNOPSIS
        Report Microsoft's built-in Conditional Access policy templates.

    .DESCRIPTION
        Reads GET /identity/conditionalAccess/templates — Microsoft's recommended CA policy
        templates, grouped by scenario (secureFoundation, zeroTrust, protectAdmins, remoteWork,
        emergingThreats). Useful as a baseline to compare a tenant's existing policies against and
        to spot missing coverage.

        Requires Policy.Read.All.

    .PARAMETER Scenario
        Filter to templates tagged with a scenario (e.g. protectAdmins).

    .PARAMETER AsReport
        Flatten Scenarios to a '; '-joined string and add ReportGeneratedUtc.

    .EXAMPLE
        Get-GkConditionalAccessTemplate

        All CA templates with their scenarios.

    .EXAMPLE
        Get-GkConditionalAccessTemplate -Scenario protectAdmins

        Templates aimed at protecting administrators.

    .EXAMPLE
        Get-GkConditionalAccessTemplate -AsReport | Export-Csv .\ca-templates.csv -NoTypeInformation

    .OUTPUTS
        PSGraphKit.CaTemplate
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.CaTemplate')]
    param(
        [string] $Scenario,
        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkConditionalAccessTemplate' | Out-Null
        $now = [datetime]::UtcNow
    }

    process {
        $templates = Invoke-GkGraphRequest -Uri '/identity/conditionalAccess/templates' -CallerFunction 'Get-GkConditionalAccessTemplate'

        foreach ($t in $templates) {
            $scenarios = @(Get-GkDictValue $t 'scenarios')
            if ($Scenario -and $Scenario -notin $scenarios) { continue }

            $obj = [ordered]@{
                PSTypeName  = 'PSGraphKit.CaTemplate'
                Name        = [string](Get-GkDictValue $t 'name')
                Description = [string](Get-GkDictValue $t 'description')
                Scenarios   = if ($AsReport) { $scenarios -join '; ' } else { $scenarios }
                Id          = [string](Get-GkDictValue $t 'id')
            }
            if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
            [pscustomobject]$obj
        }
    }
}
