function Get-GkDirectoryAudit {
    <#
    .SYNOPSIS
        Report directory audit events (who changed what) over a recent window.

    .DESCRIPTION
        Reads GET /auditLogs/directoryAudits filtered to the last -Days. Returns the activity, who
        initiated it, the result, and the target(s). Optionally narrow to a single initiator.

        Requires the AuditLog.Read.All scope. Retention is ~7 days (free) / ~30 days (P1/P2).

    .PARAMETER Days
        Look-back window in days (default 7).

    .PARAMETER InitiatedBy
        Filter to events initiated by a user (userPrincipalName).

    .PARAMETER Category
        Filter to an audit category (e.g. UserManagement, RoleManagement, ApplicationManagement).

    .PARAMETER AsReport
        Add a ReportGeneratedUtc column.

    .EXAMPLE
        Get-GkDirectoryAudit -Days 3 -Category RoleManagement

        Role-management changes in the last 3 days.

    .EXAMPLE
        Get-GkDirectoryAudit -InitiatedBy ada@contoso.com | Select-Object -First 20

        Recent changes made by one admin.

    .EXAMPLE
        Get-GkDirectoryAudit -AsReport | Export-Csv .\directory-audit.csv -NoTypeInformation

    .OUTPUTS
        PSGraphKit.DirectoryAudit
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.DirectoryAudit')]
    param(
        [ValidateRange(1, 30)]
        [int] $Days = 7,

        [string] $InitiatedBy,

        [string] $Category,

        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkDirectoryAudit' | Out-Null
        $now = [datetime]::UtcNow
    }

    process {
        $since = $now.AddDays(-$Days).ToString('yyyy-MM-ddTHH:mm:ssZ')
        $filters = @("activityDateTime ge $since")
        if ($Category) { $filters += "category eq '$Category'" }
        $uri = '/auditLogs/directoryAudits?$filter=' + ($filters -join ' and ') + '&$top=1000'

        $events = Invoke-GkGraphRequest -Uri $uri -CallerFunction 'Get-GkDirectoryAudit'

        foreach ($e in $events) {
            $initiator = Get-GkDictValue $e 'initiatedBy'
            $byUser = Get-GkDictValue $initiator 'user'
            $byApp  = Get-GkDictValue $initiator 'app'
            $actor  = if ($byUser) { [string](Get-GkDictValue $byUser 'userPrincipalName') } elseif ($byApp) { [string](Get-GkDictValue $byApp 'displayName') } else { $null }

            if ($InitiatedBy -and $actor -ne $InitiatedBy) { continue }

            $targets = @(Get-GkDictValue $e 'targetResources' | ForEach-Object { [string](Get-GkDictValue $_ 'displayName') } | Where-Object { $_ })

            $obj = [ordered]@{
                PSTypeName          = 'PSGraphKit.DirectoryAudit'
                ActivityDateTime    = ConvertTo-GkDateTime (Get-GkDictValue $e 'activityDateTime')
                ActivityDisplayName = [string](Get-GkDictValue $e 'activityDisplayName')
                Category            = [string](Get-GkDictValue $e 'category')
                Result              = [string](Get-GkDictValue $e 'result')
                InitiatedBy         = $actor
                Targets             = if ($AsReport) { $targets -join '; ' } else { $targets }
                Id                  = [string](Get-GkDictValue $e 'id')
            }
            if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
            [pscustomobject]$obj
        }
    }
}
