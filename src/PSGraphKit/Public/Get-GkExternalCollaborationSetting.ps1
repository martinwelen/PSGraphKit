function Get-GkExternalCollaborationSetting {
    <#
    .SYNOPSIS
        Report the tenant's external-collaboration and default-user-permission settings.

    .DESCRIPTION
        Reads GET /policies/authorizationPolicy and returns a single object summarizing who can
        invite guests (allowInvitesFrom), the permission level guests get (guestUserRoleId mapped to
        a friendly name), and the default permissions granted to member users (create apps, create
        security groups, read other users, ...). These are common assessment findings.

        Requires the Policy.Read.All scope.

    .PARAMETER AsReport
        Add a ReportGeneratedUtc column.

    .EXAMPLE
        Get-GkExternalCollaborationSetting

        The tenant's guest-invite and default-user-permission posture.

    .EXAMPLE
        Get-GkExternalCollaborationSetting | Select-Object AllowInvitesFrom, GuestUserRole, DefaultUserCanCreateApps

        The high-risk knobs.

    .EXAMPLE
        Get-GkExternalCollaborationSetting -AsReport | Export-Csv .\external-collab.csv -NoTypeInformation

    .OUTPUTS
        PSGraphKit.ExternalCollaborationSetting
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.ExternalCollaborationSetting')]
    param(
        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkExternalCollaborationSetting' | Out-Null
        $now = [datetime]::UtcNow
        # Well-known guest user role template IDs.
        $guestRoleNames = @{
            'a0b1b346-4d3e-4e8b-98f8-753987be4970' = 'User (same as member)'
            '10dae51f-b6af-4016-8d66-8c2a99b929b3' = 'Guest User (default)'
            '2af84b1e-32c8-42b7-82bc-daa82404023b' = 'Restricted Guest User'
        }
    }

    process {
        $p = Invoke-GkGraphRequest -Raw -Uri '/policies/authorizationPolicy' -CallerFunction 'Get-GkExternalCollaborationSetting'
        $defaults = Get-GkDictValue $p 'defaultUserRolePermissions'
        $guestRoleId = [string](Get-GkDictValue $p 'guestUserRoleId')

        $obj = [ordered]@{
            PSTypeName                       = 'PSGraphKit.ExternalCollaborationSetting'
            AllowInvitesFrom                 = [string](Get-GkDictValue $p 'allowInvitesFrom')
            GuestUserRole                    = if ($guestRoleNames.ContainsKey($guestRoleId)) { $guestRoleNames[$guestRoleId] } else { $guestRoleId }
            AllowEmailVerifiedUsersToJoin    = [bool](Get-GkDictValue $p 'allowEmailVerifiedUsersToJoinOrganization')
            AllowUserConsentForApps          = [bool](Get-GkDictValue $p 'allowUserConsentForRiskyApps')
            DefaultUserCanCreateApps         = [bool](Get-GkDictValue $defaults 'allowedToCreateApps')
            DefaultUserCanCreateSecurityGroups = [bool](Get-GkDictValue $defaults 'allowedToCreateSecurityGroups')
            DefaultUserCanReadOtherUsers     = [bool](Get-GkDictValue $defaults 'allowedToReadOtherUsers')
            GuestUserRoleId                  = $guestRoleId
        }
        if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
        [pscustomobject]$obj
    }
}
