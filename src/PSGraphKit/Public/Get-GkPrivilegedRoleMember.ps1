function Get-GkPrivilegedRoleMember {
    <#
    .SYNOPSIS
        Report members of highly privileged directory roles, flagging permanent (non-PIM)
        assignments.

    .DESCRIPTION
        Builds on Get-GkAdminRoleAssignment and narrows the result to a curated set of highly
        privileged roles (Global Administrator, Privileged Role Administrator, Security
        Administrator, Application Administrator, ...). Each row is flagged IsPermanent when it is a
        directly assigned (Active) role rather than a PIM eligible/time-bound assignment — the
        standing-privilege risk assessors look for.

        Requires the same scope as Get-GkAdminRoleAssignment (RoleManagement.Read.All). PIM data
        needs Microsoft Entra ID P2.

    .PARAMETER PermanentOnly
        Return only permanent (directly assigned, non-PIM) privileged assignments.

    .PARAMETER AsReport
        Add a ReportGeneratedUtc column.

    .EXAMPLE
        Get-GkPrivilegedRoleMember | Sort-Object RoleName

        Everyone holding a highly privileged role, active and PIM.

    .EXAMPLE
        Get-GkPrivilegedRoleMember -PermanentOnly | Where-Object RoleName -eq 'Global Administrator'

        Standing (non-PIM) Global Administrators — a key finding.

    .EXAMPLE
        Get-GkPrivilegedRoleMember -AsReport | Export-Csv .\privileged-roles.csv -NoTypeInformation

    .OUTPUTS
        PSGraphKit.PrivilegedRoleMember
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.PrivilegedRoleMember')]
    param(
        [switch] $PermanentOnly,
        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkPrivilegedRoleMember' -Caller $PSCmdlet | Out-Null
        $now = [datetime]::UtcNow
    }

    process {
        foreach ($a in (Get-GkAdminRoleAssignment)) {
            if ($a.RoleName -notin $script:GkPrivilegedRoleNames) { continue }
            $isPermanent = ($a.AssignmentKind -eq 'Active')
            if ($PermanentOnly -and -not $isPermanent) { continue }

            $obj = [ordered]@{
                PSTypeName     = 'PSGraphKit.PrivilegedRoleMember'
                RoleName       = $a.RoleName
                PrincipalName  = $a.PrincipalName
                PrincipalType  = $a.PrincipalType
                AssignmentKind = $a.AssignmentKind
                IsPermanent    = $isPermanent
                PrincipalUpn   = $a.PrincipalUpn
                PrincipalId    = $a.PrincipalId
            }
            if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
            [pscustomobject]$obj
        }
    }
}
