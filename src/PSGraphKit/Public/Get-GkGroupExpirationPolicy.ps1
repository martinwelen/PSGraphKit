function Get-GkGroupExpirationPolicy {
    <#
    .SYNOPSIS
        Report the Microsoft 365 group expiration (lifecycle) policy, if one is configured.

    .DESCRIPTION
        Reads GET /groupLifecyclePolicies. Returns the configured group-lifetime, which group types
        it applies to, and the alternate notification emails. If no policy is configured the result is
        empty (M365 groups then never auto-expire). Requires the Directory.Read.All scope.

    .PARAMETER AsReport
        Flatten AlternateNotificationEmails to a '; '-joined string and add ReportGeneratedUtc.

    .EXAMPLE
        Get-GkGroupExpirationPolicy

        The M365 group expiration policy (empty output = none configured).

    .EXAMPLE
        if (-not (Get-GkGroupExpirationPolicy)) { 'No M365 group expiration policy configured.' }

    .EXAMPLE
        Get-GkGroupExpirationPolicy -AsReport | Export-Csv .\group-expiration.csv -NoTypeInformation

    .OUTPUTS
        PSGraphKit.GroupExpirationPolicy
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.GroupExpirationPolicy')]
    param(
        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkGroupExpirationPolicy' -Caller $PSCmdlet | Out-Null
        $now = [datetime]::UtcNow
    }

    process {
        $policies = Invoke-GkGraphRequest -Uri '/groupLifecyclePolicies' -CallerFunction 'Get-GkGroupExpirationPolicy'

        foreach ($p in $policies) {
            $emails = @(Get-GkDictValue $p 'alternateNotificationEmails' | Where-Object { $_ })
            # alternateNotificationEmails is a semicolon-delimited string per the API; normalize.
            if ($emails.Count -eq 1 -and $emails[0] -like '*;*') { $emails = @($emails[0].Split(';') | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }

            $obj = [ordered]@{
                PSTypeName                  = 'PSGraphKit.GroupExpirationPolicy'
                GroupLifetimeInDays         = [int](Get-GkDictValue $p 'groupLifetimeInDays')
                ManagedGroupTypes           = [string](Get-GkDictValue $p 'managedGroupTypes')
                AlternateNotificationEmails = if ($AsReport) { $emails -join '; ' } else { , $emails }
                Id                          = [string](Get-GkDictValue $p 'id')
            }
            if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
            [pscustomobject]$obj
        }
    }
}
