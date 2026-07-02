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
        # Resolve role names via a one-time roleDefinitions lookup. (Graph rejects expanding both
        # principal and roleDefinition in one query — "only one property can be expanded" — so we
        # expand principal and map roleDefinitionId -> displayName ourselves.)
        # Key the map on BOTH id and templateId: an assignment's roleDefinitionId may reference
        # either, and for some built-in roles the two differ (an unresolved id would otherwise
        # surface as a raw GUID in RoleName).
        $roleMap = @{}
        foreach ($rd in (Invoke-GkGraphRequest -Uri '/roleManagement/directory/roleDefinitions?$select=id,displayName,templateId' -CallerFunction 'Get-GkAdminRoleAssignment')) {
            $rdName = [string](Get-GkDictValue $rd 'displayName')
            foreach ($key in @([string](Get-GkDictValue $rd 'id'), [string](Get-GkDictValue $rd 'templateId'))) {
                if ($key) { $roleMap[$key] = $rdName }
            }
        }

        $sources = @(
            @{ Kind = 'Active';    Uri = '/roleManagement/directory/roleAssignments?$expand=principal';                 Optional = $false }
            @{ Kind = 'Eligible';  Uri = '/roleManagement/directory/roleEligibilityScheduleInstances?$expand=principal'; Optional = $true }
            @{ Kind = 'TimeBound'; Uri = '/roleManagement/directory/roleAssignmentScheduleInstances?$expand=principal';  Optional = $true }
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

                $odataType = [string](Get-GkDictValue $principal '@odata.type')
                $pType = switch ($odataType) {
                    '#microsoft.graph.user'             { 'User' }
                    '#microsoft.graph.group'            { 'Group' }
                    '#microsoft.graph.servicePrincipal' { 'ServicePrincipal' }
                    default { if ($odataType) { ($odataType -split '\.')[-1] } else { 'Unknown' } }
                }

                $roleDefId = [string](Get-GkDictValue $item 'roleDefinitionId')
                if (-not $roleMap.ContainsKey($roleDefId)) {
                    # The bulk roleDefinitions list is not exhaustive for every assigned role
                    # (e.g. some first-party/service-principal assignments). Resolve this one by id
                    # and cache the result (or the id itself if it cannot be resolved at all).
                    $resolved = $roleDefId
                    try {
                        $one = Invoke-GkGraphRequest -Raw -CallerFunction 'Get-GkAdminRoleAssignment' `
                            -Uri "/roleManagement/directory/roleDefinitions/$roleDefId`?`$select=id,displayName"
                        $nm = [string](Get-GkDictValue $one 'displayName')
                        if ($nm) { $resolved = $nm }
                    }
                    catch {
                        Write-Verbose "PSGraphKit: could not resolve roleDefinition $roleDefId : $($_.Exception.Message)"
                    }
                    $roleMap[$roleDefId] = $resolved
                }
                $roleDisplayName = $roleMap[$roleDefId]
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
