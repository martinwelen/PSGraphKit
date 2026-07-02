function Get-GkAdminRoleAssignment {
    <#
    .SYNOPSIS
        Report Entra directory role assignments — active, PIM-eligible, and PIM active/time-bound —
        with the assigned principal and role resolved.

    .DESCRIPTION
        Uses the modern role-management (RBAC) API rather than the legacy directoryRoles surface:
          * Active         GET /roleManagement/directory/roleAssignments
          * Eligible (PIM)  GET /roleManagement/directory/roleEligibilityScheduleInstances
          * Time-bound (PIM) GET /roleManagement/directory/roleAssignmentScheduleInstances
        Each is expanded with principal and roleDefinition. Rows are tagged with AssignmentKind
        (Active | Eligible | TimeBound) and include the directory scope (/ = tenant-wide).

        PIM (eligible/time-bound) data requires Microsoft Entra ID P2 / Governance. If those
        endpoints are unavailable (no P2) they are skipped with a warning and active assignments
        are still returned (degrade mode: warn and continue).

    .PARAMETER AssignmentKind
        Which assignment kinds to return: All (default), Active, Eligible, or TimeBound.

    .PARAMETER RoleName
        Client-side wildcard filter on the role display name (e.g. '*Admin*').

    .PARAMETER AsReport
        Add a ReportGeneratedUtc column for clean export.

    .EXAMPLE
        Get-GkAdminRoleAssignment

        All active, eligible, and time-bound role assignments in the tenant.

    .EXAMPLE
        Get-GkAdminRoleAssignment -AssignmentKind Eligible -RoleName '*Administrator*'

        PIM-eligible assignments to any *Administrator* role.

    .EXAMPLE
        Get-GkAdminRoleAssignment |
            Group-Object RoleName |
            Sort-Object Count -Descending |
            Select-Object Name, Count

        Count of assignments per role, most-assigned first.

    .OUTPUTS
        PSGraphKit.AdminRoleAssignment
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.AdminRoleAssignment')]
    param(
        [ValidateSet('All', 'Active', 'Eligible', 'TimeBound')]
        [string] $AssignmentKind = 'All',

        [string] $RoleName,

        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkAdminRoleAssignment' | Out-Null
        $now = [datetime]::UtcNow
    }

    process {
        $sources = @(
            @{ Kind = 'Active';    Uri = '/roleManagement/directory/roleAssignments?$expand=principal,roleDefinition';                 Optional = $false }
            @{ Kind = 'Eligible';  Uri = '/roleManagement/directory/roleEligibilityScheduleInstances?$expand=principal,roleDefinition'; Optional = $true }
            @{ Kind = 'TimeBound'; Uri = '/roleManagement/directory/roleAssignmentScheduleInstances?$expand=principal,roleDefinition';  Optional = $true }
        )

        foreach ($source in $sources) {
            if ($AssignmentKind -ne 'All' -and $AssignmentKind -ne $source.Kind) { continue }

            try {
                $items = Invoke-GkGraphRequest -Uri $source.Uri -CallerFunction 'Get-GkAdminRoleAssignment'
            }
            catch {
                if ($source.Optional) {
                    Write-Warning "Could not read PIM $($source.Kind) assignments (requires Microsoft Entra ID P2 / Governance). Skipping. Underlying error: $($_.Exception.Message)"
                    continue
                }
                throw
            }

            foreach ($item in $items) {
                $principal = Get-GkDictValue $item 'principal'
                $roleDef   = Get-GkDictValue $item 'roleDefinition'

                $odataType = [string](Get-GkDictValue $principal '@odata.type')
                $pType = switch ($odataType) {
                    '#microsoft.graph.user'             { 'User' }
                    '#microsoft.graph.group'            { 'Group' }
                    '#microsoft.graph.servicePrincipal' { 'ServicePrincipal' }
                    default { if ($odataType) { ($odataType -split '\.')[-1] } else { 'Unknown' } }
                }

                $roleDisplayName = [string](Get-GkDictValue $roleDef 'displayName')
                if ($RoleName -and $roleDisplayName -notlike $RoleName) { continue }

                $scope = [string](Get-GkDictValue $item 'directoryScopeId')

                $obj = [ordered]@{
                    PSTypeName        = 'PSGraphKit.AdminRoleAssignment'
                    RoleName          = $roleDisplayName
                    AssignmentKind    = $source.Kind
                    PrincipalName     = [string](Get-GkDictValue $principal 'displayName')
                    PrincipalUpn      = [string](Get-GkDictValue $principal 'userPrincipalName')
                    PrincipalType     = $pType
                    Scope             = $scope
                    IsTenantScope     = ($scope -eq '/')
                    AssignmentType    = [string](Get-GkDictValue $item 'assignmentType')
                    MemberType        = [string](Get-GkDictValue $item 'memberType')
                    StartDateTime     = ConvertTo-GkDateTime (Get-GkDictValue $item 'startDateTime')
                    EndDateTime       = ConvertTo-GkDateTime (Get-GkDictValue $item 'endDateTime')
                    RoleDefinitionId  = [string](Get-GkDictValue $item 'roleDefinitionId')
                    PrincipalId       = [string](Get-GkDictValue $item 'principalId')
                }
                if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
                [pscustomobject]$obj
            }
        }
    }
}
