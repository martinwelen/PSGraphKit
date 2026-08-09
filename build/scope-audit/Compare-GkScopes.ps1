# Reconcile PSGraphKit's scope map against the Learn-sourced permissions for every call it makes.
param(
    [string] $Inventory = "$PSScriptRoot\call-inventory-final.csv",
    [string] $LearnPerms = "$PSScriptRoot\learn-permissions.csv",
    [string] $Repo = 'C:\dev\PSGraphKit',
    [string] $OutFile = "$PSScriptRoot\reconciliation.csv"
)
$ErrorActionPreference = 'Stop'

function Split-PermissionList {
    param([string] $S)
    if (-not $S) { return @() }
    if ($S -match '^\s*(Not supported|Not available)') { return @() }
    # "GroupMember.ReadWrite.All and Device.Read.All" -> both are required; list both as known-valid.
    @($S -split '[,;]| and ' | ForEach-Object { $_.Trim().TrimEnd('.') } |
        Where-Object { $_ -and $_ -notmatch '^(Not supported|Not available)$' -and $_ -match '^[A-Za-z]' })
}

$calls = Import-Csv $Inventory
$perms = @{}
foreach ($r in Import-Csv $LearnPerms) {
    $all = @()
    $all += Split-PermissionList $r.DelegatedLeast
    $all += Split-PermissionList $r.DelegatedHigher
    $all += Split-PermissionList $r.AppLeast
    $all += Split-PermissionList $r.AppHigher
    $perms[$r.Endpoint] = [pscustomobject]@{
        All   = @($all | Select-Object -Unique)
        Least = @(@(Split-PermissionList $r.DelegatedLeast) + @(Split-PermissionList $r.AppLeast) | Select-Object -Unique)
        Doc   = $r.Doc
    }
}

# /directory/deletedItems documents one least-privileged permission per resource type in a matrix,
# not a least/higher table, so the generated include is empty. Read manually from
# directory-deleteditems-list.md; Directory.Read.All serves all of them as the broad directory read.
$deletedItemPerms = @{
    'user'               = @('User.Read.All', 'Directory.Read.All')
    'group'              = @('Group.Read.All', 'Directory.Read.All')
    'application'        = @('Application.Read.All', 'Directory.Read.All')
    'servicePrincipal'   = @('Application.Read.All', 'Directory.Read.All')
    'administrativeUnit' = @('AdministrativeUnit.Read.All', 'Directory.Read.All')
}
foreach ($t in $deletedItemPerms.Keys) {
    $perms["GET /directory/deletedItems/microsoft.graph.$t"] = [pscustomobject]@{
        All   = $deletedItemPerms[$t]
        Least = @($deletedItemPerms[$t][0])
        Doc   = 'directory-deleteditems-list.md (resource-type matrix, read manually)'
    }
}

# POST /directory/deletedItems/{id}/restore uses the same per-resource-type matrix. The union of
# every restorable type is what the cmdlet's base entry may legitimately offer; the per-type
# variants are checked against their own row. Read manually from directory-deleteditems-restore.md.
$perms['POST /directory/deletedItems/{id}/restore'] = [pscustomobject]@{
    All   = @('User.DeleteRestore.All', 'User.ReadWrite.All', 'Group.ReadWrite.All',
              'Application.ReadWrite.All', 'AdministrativeUnit.ReadWrite.All', 'Directory.ReadWrite.All')
    Least = @('User.DeleteRestore.All')
    Doc   = 'directory-deleteditems-restore.md (resource-type matrix, read manually)'
}

# POST /groups/{id}/members/$ref uses a per-resource-type matrix rather than a least/higher table.
# For adding a user (what Add-GkGroupMember does) the documented least privileged permission is
# GroupMember.ReadWrite.All; the broader group/directory write scopes also serve it.
$perms['POST /groups/{id}/members/$ref'] = [pscustomobject]@{
    All   = @('GroupMember.ReadWrite.All', 'Group.ReadWrite.All', 'Directory.ReadWrite.All')
    Least = @('GroupMember.ReadWrite.All')
    Doc   = 'group-post-members.md (resource-type matrix, read manually)'
}

# Property-level requirements documented OUTSIDE the main permissions table. The generated
# include only covers the resource as a whole, so these must be supplied by hand from the prose
# on the same Learn page.
$propertyLevel = @{
    'PATCH /users/{id}' = @('User.EnableDisableAccount.All', 'User.Read.All', 'Directory.Read.All',
                            'User-PasswordProfile.ReadWrite.All', 'User-Mail.ReadWrite.All', 'User-Phone.ReadWrite.All')
    # signInActivity on user requires AuditLog.Read.All in addition to a user-read scope.
    'GET /users'        = @('AuditLog.Read.All')
}
foreach ($ep in $propertyLevel.Keys) {
    if ($perms.ContainsKey($ep)) {
        $perms[$ep] = [pscustomobject]@{
            All   = @(@($perms[$ep].All) + $propertyLevel[$ep] | Select-Object -Unique)
            Least = $perms[$ep].Least
            Doc   = "$($perms[$ep].Doc) + property-level notes"
        }
    }
}

Import-Module "$Repo\src\PSGraphKit\PSGraphKit.psd1" -Force
$scopeMap = & (Get-Module PSGraphKit) { $script:GkScopeMap }

$report = foreach ($cmdlet in ($calls.Cmdlet | Select-Object -Unique | Sort-Object)) {
    $myCalls = @($calls | Where-Object Cmdlet -eq $cmdlet)
    $acceptedAll = @(); $leastPerCall = @(); $missingDoc = @()
    foreach ($c in $myCalls) {
        $ep = "$($c.Method) $($c.Path)"
        if (-not $perms.ContainsKey($ep)) { $missingDoc += $ep; continue }
        $acceptedAll += $perms[$ep].All
        $leastPerCall += [pscustomobject]@{ Endpoint = $ep; Least = $perms[$ep].Least }
    }
    $acceptedAll = @($acceptedAll | Select-Object -Unique)

    $keys = @($scopeMap.Keys | Where-Object { $_ -eq $cmdlet -or $_ -like "${cmdlet}:*" })
    $mapped = @()
    foreach ($k in $keys) { $mapped += @($scopeMap[$k].Groups | ForEach-Object { $_.Any }) }
    $mapped = @($mapped | Select-Object -Unique)

    # Scopes we offer that no call of this cmdlet accepts -> pre-flight passes, Graph 403s.
    $overPermissive = @($mapped | Where-Object { $acceptedAll -notcontains $_ })
    # A call whose documented least-privileged options are ALL absent from our map -> false rejection
    # for a caller holding exactly the least-privileged scope.
    $strictCalls = @(
        foreach ($lp in $leastPerCall) {
            if ($lp.Least.Count -eq 0) { continue }
            $covered = @($lp.Least | Where-Object { $mapped -contains $_ })
            if ($covered.Count -eq 0) { "$($lp.Endpoint) -> least: $($lp.Least -join ', ')" }
        }
    )

    [pscustomobject]@{
        Cmdlet         = $cmdlet
        Calls          = $myCalls.Count
        MapDeclares    = $mapped -join ', '
        OverPermissive = $overPermissive -join ', '
        StrictCalls    = $strictCalls -join ' ; '
        MissingDoc     = $missingDoc -join ' ; '
        Verdict        = @(
            if ($overPermissive) { 'OVER-PERMISSIVE' }
            if ($strictCalls)    { 'TOO-STRICT' }
            if ($missingDoc)     { 'UNDOCUMENTED' }
        ) -join '+'
    }
}
$report | ForEach-Object { if (-not $_.Verdict) { $_.Verdict = 'OK' } }
$report | Export-Csv $OutFile -NoTypeInformation -Encoding utf8

Write-Output "=== verdicts ==="
$report | Group-Object Verdict | Sort-Object Name | ForEach-Object { "{0,-24} {1}" -f $_.Name, $_.Count }
Write-Output ""
Write-Output "=== OVER-PERMISSIVE (pre-flight passes, Graph would 403) ==="
$report | Where-Object Verdict -like '*OVER-PERMISSIVE*' | ForEach-Object {
    "{0}`n    offers but no call accepts: {1}" -f $_.Cmdlet, $_.OverPermissive
}
Write-Output ""
Write-Output "=== TOO-STRICT (a caller with the documented least-privileged scope is rejected) ==="
$report | Where-Object Verdict -like '*TOO-STRICT*' | ForEach-Object {
    "{0}`n    {1}" -f $_.Cmdlet, $_.StrictCalls
}
