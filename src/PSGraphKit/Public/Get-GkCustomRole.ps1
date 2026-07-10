function Get-GkCustomRole {
    <#
    .SYNOPSIS
        Report custom (non-built-in) directory role definitions and their permissions.

    .DESCRIPTION
        Reads GET /roleManagement/directory/roleDefinitions filtered to isBuiltIn eq false, and
        returns each custom role with whether it is enabled and the resource actions it grants.

        Requires RoleManagement.Read.Directory.

    .PARAMETER AsReport
        Flatten Permissions to a '; '-joined string and add ReportGeneratedUtc.

    .EXAMPLE
        Get-GkCustomRole

        All custom directory roles with their allowed actions.

    .EXAMPLE
        Get-GkCustomRole | Where-Object { -not $_.IsEnabled }

        Custom roles that are defined but disabled.

    .EXAMPLE
        Get-GkCustomRole -AsReport | Export-Csv .\custom-roles.csv -NoTypeInformation

    .OUTPUTS
        PSGraphKit.CustomRole
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.CustomRole')]
    param(
        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkCustomRole' | Out-Null
        $now = [datetime]::UtcNow
    }

    process {
        $roles = Invoke-GkGraphRequest -Uri '/roleManagement/directory/roleDefinitions?$filter=isBuiltIn eq false' -CallerFunction 'Get-GkCustomRole'

        foreach ($r in $roles) {
            $actions = @(Get-GkDictValue $r 'rolePermissions' | ForEach-Object { @(Get-GkDictValue $_ 'allowedResourceActions') } | Where-Object { $_ })

            $obj = [ordered]@{
                PSTypeName      = 'PSGraphKit.CustomRole'
                DisplayName     = [string](Get-GkDictValue $r 'displayName')
                IsEnabled       = [bool](Get-GkDictValue $r 'isEnabled')
                Description     = [string](Get-GkDictValue $r 'description')
                PermissionCount = $actions.Count
                Permissions     = if ($AsReport) { $actions -join '; ' } else { , $actions }
                TemplateId      = [string](Get-GkDictValue $r 'templateId')
                Id              = [string](Get-GkDictValue $r 'id')
            }
            if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
            [pscustomobject]$obj
        }
    }
}
