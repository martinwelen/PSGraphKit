function Get-GkRoleDefinition {
    <#
    .SYNOPSIS
        List directory role definitions — built-in and custom — with their permission counts.

    .DESCRIPTION
        Reads GET /roleManagement/directory/roleDefinitions and returns every role the tenant can
        assign, so you can answer "what does this role actually allow" without leaving the shell.
        Get-GkCustomRole covers only the custom roles; this is the full catalogue, and it is the
        lookup behind the role names reported by Get-GkAdminRoleAssignment.

        Requires RoleManagement.Read.Directory (or Directory.Read.All).

    .PARAMETER Name
        Only return roles whose display name contains this text (case-insensitive).

    .PARAMETER Scope
        Only return built-in roles, only custom roles, or all. Defaults to All.

    .PARAMETER IncludePermission
        Add a Permissions column listing the allowed resource actions. These lists are long, so
        they are omitted by default.

    .PARAMETER AsReport
        Add a ReportGeneratedUtc column.

    .EXAMPLE
        Get-GkRoleDefinition -Name 'administrator' | Sort-Object DisplayName

        Every role with "administrator" in its name.

    .EXAMPLE
        Get-GkRoleDefinition -Scope Custom -IncludePermission

        Custom roles with the actions they grant.

    .EXAMPLE
        Get-GkRoleDefinition -AsReport | Export-Csv .\roles.csv -NoTypeInformation

    .OUTPUTS
        PSGraphKit.RoleDefinition
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.RoleDefinition')]
    param(
        [string] $Name,

        [ValidateSet('All', 'BuiltIn', 'Custom')]
        [string] $Scope = 'All',

        [switch] $IncludePermission,

        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkRoleDefinition' -Caller $PSCmdlet | Out-Null
        $now = [datetime]::UtcNow
    }

    process {
        # isBuiltIn supports $filter server-side; the name match is a 'contains', which Graph does
        # not support on this collection, so it stays client-side.
        $uri = '/roleManagement/directory/roleDefinitions'
        if ($Scope -eq 'BuiltIn') { $uri += '?$filter=isBuiltIn eq true' }
        elseif ($Scope -eq 'Custom') { $uri += '?$filter=isBuiltIn eq false' }

        $roles = Invoke-GkGraphRequest -Uri $uri -CallerFunction 'Get-GkRoleDefinition'

        foreach ($r in $roles) {
            $display = [string](Get-GkDictValue $r 'displayName')
            if ($Name -and $display -notlike "*$Name*") { continue }

            # rolePermissions is a collection of { allowedResourceActions: [...] }.
            $actions = @(
                foreach ($p in @(Get-GkDictValue $r 'rolePermissions')) {
                    @(Get-GkDictValue $p 'allowedResourceActions')
                }
            ) | Where-Object { $_ }

            $obj = [ordered]@{
                PSTypeName      = 'PSGraphKit.RoleDefinition'
                DisplayName     = $display
                IsBuiltIn       = Get-GkDictValue $r 'isBuiltIn'
                IsEnabled       = Get-GkDictValue $r 'isEnabled'
                PermissionCount = @($actions).Count
                Description     = [string](Get-GkDictValue $r 'description')
                TemplateId      = [string](Get-GkDictValue $r 'templateId')
                Id              = [string](Get-GkDictValue $r 'id')
            }
            if ($IncludePermission) {
                # [string[]] keeps a single-action list an array without the ,@() wrapper, which
                # would nest the array one level deep.
                if ($AsReport) { $obj['Permissions'] = (@($actions) -join '; ') }
                else { $obj['Permissions'] = [string[]]@($actions) }
            }
            if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
            [pscustomobject]$obj
        }
    }
}
