function Get-GkDeletedItem {
    <#
    .SYNOPSIS
        List soft-deleted directory objects still inside the 30-day restore window.

    .DESCRIPTION
        Reads GET /directory/deletedItems/microsoft.graph.{type} and reports what was deleted, when,
        and how long is left to restore it. Deleted users, groups and applications sit in a
        recoverable container for 30 days before Entra purges them permanently.

        This is the safety net behind the module's delete paths: Remove-GkStaleGuest -Delete and
        Disable-GkStaleDevice -Delete both soft-delete, so anything they removed by mistake shows up
        here until the window closes.

        Scopes depend on what you ask for and only the one in use is validated: User.Read.All for
        users, Group.Read.All for groups, Application.Read.All for applications and service
        principals, AdministrativeUnit.Read.All for administrative units.

    .PARAMETER Type
        The directory object type to list. Required — Graph has no "all deleted objects" endpoint.

    .PARAMETER DeletedWithinDays
        Only return objects deleted within this many days.

    .PARAMETER ExpiringInDays
        Only return objects whose restore window closes within this many days. Use it to catch
        anything about to be purged.

    .PARAMETER First
        Return at most this many objects.

    .PARAMETER AsReport
        Add a ReportGeneratedUtc column.

    .EXAMPLE
        Get-GkDeletedItem -Type User

        Every recoverable deleted user.

    .EXAMPLE
        Get-GkDeletedItem -Type Group -ExpiringInDays 5

        Deleted groups with fewer than five days left to restore.

    .EXAMPLE
        Get-GkDeletedItem -Type User -AsReport | Export-Csv .\deleted-users.csv -NoTypeInformation

    .OUTPUTS
        PSGraphKit.DeletedItem
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.DeletedItem')]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('User', 'Group', 'Application', 'ServicePrincipal', 'AdministrativeUnit')]
        [string] $Type,

        [int] $DeletedWithinDays,

        [int] $ExpiringInDays,

        [int] $First,

        [switch] $AsReport
    )

    begin {
        # Each type is a different Graph permission, so validate the one actually being read.
        Test-GkConnection -FunctionName 'Get-GkDeletedItem' -Variant $Type -Caller $PSCmdlet | Out-Null
        $now = [datetime]::UtcNow

        # Entra keeps soft-deleted directory objects for 30 days before permanent purge.
        $retentionDays = 30
    }

    process {
        # The type is a cast segment in the path, not a filter; Graph has no combined collection.
        $segment = 'microsoft.graph.' + $Type.Substring(0, 1).ToLower() + $Type.Substring(1)

        # deletedDateTime is NOT in the default property set this endpoint returns, so it has to be
        # asked for explicitly. Without it every DeletedDateTime/DaysSinceDeleted/DaysUntilPurge is
        # null and -DeletedWithinDays / -ExpiringInDays filter every row away. userPrincipalName only
        # exists on users; requesting it for another type is a 400.
        $select = 'id,displayName,deletedDateTime'
        if ($Type -eq 'User') { $select += ',userPrincipalName' }

        $params = @{
            Uri            = "/directory/deletedItems/$segment`?`$select=$select"
            CallerFunction = 'Get-GkDeletedItem'
        }
        if ($PSBoundParameters.ContainsKey('First')) { $params['MaxResult'] = $First }

        $items = Invoke-GkGraphRequest @params

        foreach ($i in $items) {
            $deleted = ConvertTo-GkDateTime (Get-GkDictValue $i 'deletedDateTime')
            $ageDays = if ($null -ne $deleted) { [int][math]::Floor(($now - $deleted).TotalDays) } else { $null }
            $daysLeft = if ($null -ne $ageDays) { $retentionDays - $ageDays } else { $null }

            if ($PSBoundParameters.ContainsKey('DeletedWithinDays')) {
                if ($null -eq $ageDays -or $ageDays -gt $DeletedWithinDays) { continue }
            }
            if ($PSBoundParameters.ContainsKey('ExpiringInDays')) {
                if ($null -eq $daysLeft -or $daysLeft -gt $ExpiringInDays) { continue }
            }

            $obj = [ordered]@{
                PSTypeName        = 'PSGraphKit.DeletedItem'
                ObjectType        = $Type
                DisplayName       = [string](Get-GkDictValue $i 'displayName')
                UserPrincipalName = [string](Get-GkDictValue $i 'userPrincipalName')
                DeletedDateTime   = $deleted
                DaysSinceDeleted  = $ageDays
                DaysUntilPurge    = $daysLeft
                Id                = [string](Get-GkDictValue $i 'id')
            }
            if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
            [pscustomobject]$obj
        }
    }
}
