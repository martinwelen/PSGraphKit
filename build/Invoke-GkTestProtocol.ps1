#Requires -Version 7.4
<#
.SYNOPSIS
    Full read-only validation protocol for PSGraphKit against a live Microsoft Graph tenant.

.DESCRIPTION
    Runs every read (Get-*) cmdlet end-to-end and validates the SHAPE of what each one returns —
    not merely that the call succeeded. This is the layer that catches the class of bug fixed in
    0.3.2, where a cmdlet returns a well-formed, correctly-typed object with EVERY field null/blank.
    A row-count-only smoke test reports that as "OK, 1 row"; this protocol flags it.

    Three checks are applied to every returned row:

      * Type    - each emitted object is a 'PSGraphKit.*' typed object. A raw Graph array/hashtable
                  that leaked through (the coarser failure mode) shows up here as a non-PSGraphKit type.
      * Content - the row is not "hollow": it must carry at least one populated text / date / object
                  field. A row whose descriptive fields are all null/blank (numbers left at 0) is the
                  exact signature of the 0.3.1 Get-GkSecureScore / Get-GkTenantInfo bug.
      * Keys    - for cmdlets with a declared KeyFields list, those fields must be populated on every
                  row. This is the precise, tenant-agnostic check; extend it as you learn each schema.

    READ-ONLY. No writes, no state changes — safe against any tenant you can read. Write cmdlets are
    intentionally excluded: -WhatIf short-circuits before producing a result object, so they cannot be
    shape-validated live. Validate those manually against disposable objects; they are covered by unit
    tests. See docs/TEST-PROTOCOL.md for the full protocol (unit + live layers and the release gate).

    Microsoft Graph auth is interactive and does not survive across separate processes, so run this in
    YOUR OWN terminal, not through an automated tool. Connect first (or pass -Login):

        Connect-GkGraph -AllCommands
        ./build/Invoke-GkTestProtocol.ps1

    A cmdlet that returns zero rows is reported EMPTY (informational) — its shape could not be checked
    because the tenant had no data (e.g. no risky users without Entra ID P2). That is a coverage gap,
    not a pass; the seam-level unit tests carry those cases.

.PARAMETER Login
    Connect first via Connect-GkGraph -AllCommands (interactive sign-in) before validating.

.PARAMETER UserId
    User (UPN or object id) for Get-GkUserAccessReport. Defaults to the signed-in account.

.PARAMETER IncludeAssessment
    Also run Export-GkTenantAssessment (writes an HTML/CSV report to disk under the current directory).

.EXAMPLE
    ./build/Invoke-GkTestProtocol.ps1 -Login

.EXAMPLE
    Connect-GkGraph -AllCommands
    ./build/Invoke-GkTestProtocol.ps1 -UserId ada@contoso.com
#>
[CmdletBinding()]
param(
    [switch] $Login,
    [string] $UserId,
    [switch] $IncludeAssessment
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

if ($Login) {
    Write-Information 'Connecting (interactive) with the full read-only scope set...' -InformationAction Continue
    Connect-GkGraph -AllCommands | Out-Null
}

$ctx = Get-MgContext
if (-not $ctx) {
    throw "Not connected. Run 'Connect-GkGraph -AllCommands' first, or pass -Login."
}
Write-Information "Connected as $($ctx.Account) ($($ctx.AuthType)) in tenant $($ctx.TenantId)." -InformationAction Continue
if (-not $UserId) { $UserId = $ctx.Account }

# --- Content heuristic --------------------------------------------------------------------------
# Does a row carry any real descriptive data? Numbers and booleans do NOT count as content: the
# consumption bug leaves numeric fields at 0 while nulling every string/date/object field, so a row
# with no populated text/date/object member is almost certainly hollow.
function Test-GkRowHasContent {
    param([Parameter(Mandatory)] $Row)
    foreach ($p in $Row.PSObject.Properties) {
        $v = $p.Value
        if ($null -eq $v) { continue }
        if ($v -is [string]) { if ($v.Trim().Length -gt 0) { return $true } ; continue }
        if ($v -is [datetime] -or $v -is [System.DateTimeOffset]) { return $true }
        if ($v -is [bool]) { continue }
        if ($v -is [System.ValueType]) { continue }   # numbers / enums are not "content" here
        if ($v -is [System.Collections.IEnumerable]) { if (@($v).Count -gt 0) { return $true } ; continue }
        return $true                                   # any other populated object counts
    }
    return $false
}

# Is a specific field populated (non-null, non-blank) on a row?
function Test-GkFieldPopulated {
    param($Row, [string] $Field)
    $prop = $Row.PSObject.Properties[$Field]
    if (-not $prop) { return $false }
    $v = $prop.Value
    if ($null -eq $v) { return $false }
    if ($v -is [string]) { return $v.Trim().Length -gt 0 }
    return $true
}

# --- Probe specs (read-only) --------------------------------------------------------------------
# Type      : the PSTypeName every row must carry.
# KeyFields : fields that must be populated on every row in a healthy tenant (precise check).
#             Curated conservatively; add to these as each cmdlet's output schema is confirmed.
$specs = @(
    @{ Name = 'Get-GkConnectionInfo';              Type = 'PSGraphKit.ConnectionInfo';              Key = @();                          Invoke = { Get-GkConnectionInfo } }
    @{ Name = 'Get-GkTenantInfo';                  Type = 'PSGraphKit.TenantInfo';                  Key = @('TenantId', 'DisplayName'); Invoke = { Get-GkTenantInfo } }
    @{ Name = 'Get-GkDomain';                      Type = 'PSGraphKit.Domain';                      Key = @();                          Invoke = { Get-GkDomain } }
    @{ Name = 'Get-GkSubscription';                Type = 'PSGraphKit.Subscription';                Key = @();                          Invoke = { Get-GkSubscription } }
    @{ Name = 'Get-GkLicenseOverview';             Type = 'PSGraphKit.LicenseOverview';             Key = @();                          Invoke = { Get-GkLicenseOverview } }
    @{ Name = 'Get-GkLicenseAssignmentError';      Type = 'PSGraphKit.LicenseAssignmentError';      Key = @();                          Invoke = { Get-GkLicenseAssignmentError } }
    @{ Name = 'Get-GkStaleUser';                   Type = 'PSGraphKit.StaleUser';                   Key = @();                          Invoke = { Get-GkStaleUser -InactiveDays 90 } }
    @{ Name = 'Get-GkGuestInventory';              Type = 'PSGraphKit.GuestInventory';              Key = @();                          Invoke = { Get-GkGuestInventory -SkipSponsor } }
    @{ Name = 'Get-GkUserMfaStatus';               Type = 'PSGraphKit.UserMfaStatus';               Key = @();                          Invoke = { Get-GkUserMfaStatus } }
    @{ Name = 'Get-GkUserAccessReport';            Type = 'PSGraphKit.UserAccessReport';            Key = @();                          Invoke = { Get-GkUserAccessReport -UserId $UserId } }
    @{ Name = 'Get-GkAdminRoleAssignment';         Type = 'PSGraphKit.AdminRoleAssignment';         Key = @('RoleName');                Invoke = { Get-GkAdminRoleAssignment } }
    @{ Name = 'Get-GkPrivilegedRoleMember';        Type = 'PSGraphKit.PrivilegedRoleMember';        Key = @();                          Invoke = { Get-GkPrivilegedRoleMember } }
    @{ Name = 'Get-GkCustomRole';                  Type = 'PSGraphKit.CustomRole';                  Key = @();                          Invoke = { Get-GkCustomRole } }
    @{ Name = 'Get-GkRoleAssignableGroup';         Type = 'PSGraphKit.RoleAssignableGroup';         Key = @();                          Invoke = { Get-GkRoleAssignableGroup } }
    @{ Name = 'Get-GkAdministrativeUnit';          Type = 'PSGraphKit.AdministrativeUnit';          Key = @();                          Invoke = { Get-GkAdministrativeUnit } }
    @{ Name = 'Get-GkGroupReport';                 Type = 'PSGraphKit.GroupReport';                 Key = @();                          Invoke = { Get-GkGroupReport -SkipMemberCount } }
    @{ Name = 'Get-GkGroupExpirationPolicy';       Type = 'PSGraphKit.GroupExpirationPolicy';       Key = @();                          Invoke = { Get-GkGroupExpirationPolicy } }
    @{ Name = 'Get-GkDeviceInventory';             Type = 'PSGraphKit.Device';                      Key = @();                          Invoke = { Get-GkDeviceInventory } }
    @{ Name = 'Get-GkAppRegistrationReport';       Type = 'PSGraphKit.AppRegistration';             Key = @();                          Invoke = { Get-GkAppRegistrationReport } }
    @{ Name = 'Get-GkServicePrincipalReport';      Type = 'PSGraphKit.ServicePrincipal';            Key = @();                          Invoke = { Get-GkServicePrincipalReport } }
    @{ Name = 'Get-GkInactiveApp';                 Type = 'PSGraphKit.InactiveApp';                 Key = @();                          Invoke = { Get-GkInactiveApp } }
    @{ Name = 'Get-GkStaleAppCredential';          Type = 'PSGraphKit.StaleAppCredential';          Key = @();                          Invoke = { Get-GkStaleAppCredential } }
    @{ Name = 'Get-GkConsentRequest';              Type = 'PSGraphKit.ConsentRequest';              Key = @();                          Invoke = { Get-GkConsentRequest } }
    @{ Name = 'Get-GkCaPolicyReport';              Type = 'PSGraphKit.CaPolicy';                    Key = @();                          Invoke = { Get-GkCaPolicyReport } }
    @{ Name = 'Get-GkNamedLocation';               Type = 'PSGraphKit.NamedLocation';               Key = @();                          Invoke = { Get-GkNamedLocation } }
    @{ Name = 'Get-GkConditionalAccessTemplate';   Type = 'PSGraphKit.CaTemplate';                  Key = @();                          Invoke = { Get-GkConditionalAccessTemplate } }
    @{ Name = 'Get-GkAuthMethodPolicy';            Type = 'PSGraphKit.AuthMethodState';             Key = @();                          Invoke = { Get-GkAuthMethodPolicy } }
    @{ Name = 'Get-GkAuthStrengthPolicy';          Type = 'PSGraphKit.AuthStrengthPolicy';          Key = @();                          Invoke = { Get-GkAuthStrengthPolicy } }
    @{ Name = 'Get-GkExternalCollaborationSetting'; Type = 'PSGraphKit.ExternalCollaborationSetting'; Key = @();                        Invoke = { Get-GkExternalCollaborationSetting } }
    @{ Name = 'Get-GkCrossTenantAccess';           Type = 'PSGraphKit.CrossTenantAccess';           Key = @();                          Invoke = { Get-GkCrossTenantAccess } }
    @{ Name = 'Get-GkSecureScore';                 Type = 'PSGraphKit.SecureScore';                 Key = @('ScoreDate');               Invoke = { Get-GkSecureScore } }
    @{ Name = 'Get-GkRiskyUser';                   Type = 'PSGraphKit.RiskyUser';                   Key = @();                          Invoke = { Get-GkRiskyUser } }
    @{ Name = 'Get-GkRiskDetection';               Type = 'PSGraphKit.RiskDetection';               Key = @();                          Invoke = { Get-GkRiskDetection } }
    @{ Name = 'Get-GkSignInReport';                Type = 'PSGraphKit.SignIn';                      Key = @();                          Invoke = { Get-GkSignInReport } }
    @{ Name = 'Get-GkLegacyAuthSignIn';            Type = 'PSGraphKit.SignIn';                      Key = @();                          Invoke = { Get-GkLegacyAuthSignIn } }
    @{ Name = 'Get-GkDirectoryAudit';              Type = 'PSGraphKit.DirectoryAudit';              Key = @();                          Invoke = { Get-GkDirectoryAudit } }
)

if ($IncludeAssessment) {
    $specs += @{ Name = 'Export-GkTenantAssessment'; Type = $null; Key = @(); Invoke = { Export-GkTenantAssessment } }
}

# --- Run + validate ------------------------------------------------------------------------------
# Results stream one line per cmdlet as each completes (a full run can take several minutes against a
# real tenant — sign-in/audit logs and all-user scans are the slow ones), with a Write-Progress
# indicator so an in-flight or slow cmdlet is always visible.
$results = [System.Collections.Generic.List[object]]::new()
$i = 0
$n = $specs.Count
Write-Information ("Running {0} read cmdlets; each result prints as it completes..." -f $n) -InformationAction Continue

foreach ($spec in $specs) {
    $i++
    Write-Progress -Activity 'PSGraphKit test protocol' -Status ("{0} ({1}/{2})" -f $spec.Name, $i, $n) -PercentComplete ([int](100 * $i / $n))
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $warns = @()
    try {
        $out = Invoke-Command -ScriptBlock $spec.Invoke -WarningVariable warns -WarningAction SilentlyContinue
        $sw.Stop()
        $rows = @($out)

        $status = 'OK'
        $note = ''

        if ($rows.Count -eq 0) {
            $status = 'EMPTY'
            $note = 'no rows — shape not validated (tenant has no data)'
        }
        else {
            # Type: every row must be the declared PSGraphKit type (skip when Type is $null, e.g. Export).
            $badType = @()
            if ($spec.Type) {
                $badType = @($rows | Where-Object { $_.PSObject.TypeNames[0] -ne $spec.Type })
            }
            # Content: no hollow rows (the all-fields-null signature).
            $hollow = @($rows | Where-Object { -not (Test-GkRowHasContent $_) })
            # Keys: declared key fields populated on every row.
            $keyMiss = @()
            foreach ($k in $spec.Key) {
                $keyMiss += @($rows | Where-Object { -not (Test-GkFieldPopulated $_ $k) } | ForEach-Object { $k })
            }

            if ($badType.Count -gt 0) {
                $status = 'BADTYPE'
                $note = "returned $($badType.Count) object(s) of type '$($badType[0].PSObject.TypeNames[0])', expected '$($spec.Type)'"
            }
            elseif ($hollow.Count -gt 0) {
                $status = 'HOLLOW'
                $note = "$($hollow.Count) of $($rows.Count) row(s) have no populated text/date field — likely a data-consumption bug"
            }
            elseif ($keyMiss.Count -gt 0) {
                $status = 'KEYFIELD'
                $note = "empty required field(s): $(( $keyMiss | Select-Object -Unique ) -join ', ')"
            }
            elseif ($warns.Count -gt 0) {
                $status = 'WARN'
                $note = ([string]$warns[0]).Split([char]10)[0]
            }
        }

        $row = [pscustomobject]@{
            Cmdlet  = $spec.Name
            Status  = $status
            Rows    = $rows.Count
            Seconds = [math]::Round($sw.Elapsed.TotalSeconds, 1)
            Note    = $note
        }
    }
    catch {
        $sw.Stop()
        $row = [pscustomobject]@{
            Cmdlet  = $spec.Name
            Status  = 'FAIL'
            Rows    = 0
            Seconds = [math]::Round($sw.Elapsed.TotalSeconds, 1)
            Note    = $_.Exception.Message.Split([char]10)[0]
        }
    }

    $results.Add($row)
    Write-Information ("  [{0,2}/{1}] {2,-9} {3,-34} {4,5} row(s) {5,6}s  {6}" -f `
            $i, $n, $row.Status, $row.Cmdlet, $row.Rows, $row.Seconds, $row.Note) -InformationAction Continue
}

Write-Progress -Activity 'PSGraphKit test protocol' -Completed
Write-Information '' -InformationAction Continue

# FAIL / BADTYPE / HOLLOW / KEYFIELD are hard problems; EMPTY / WARN are informational.
$bad  = @($results | Where-Object Status -in 'FAIL', 'BADTYPE', 'HOLLOW', 'KEYFIELD')
$empty = @($results | Where-Object Status -eq 'EMPTY')
$warn = @($results | Where-Object Status -eq 'WARN')
$ok   = @($results | Where-Object Status -eq 'OK')

Write-Information ("Protocol: {0} OK, {1} WARN, {2} EMPTY, {3} PROBLEM (of {4})." -f `
        $ok.Count, $warn.Count, $empty.Count, $bad.Count, $results.Count) -InformationAction Continue

if ($bad.Count -gt 0) {
    Write-Information '' -InformationAction Continue
    Write-Information 'PROBLEMS — investigate before shipping:' -InformationAction Continue
    foreach ($b in $bad) {
        Write-Information ("  [{0}] {1}: {2}" -f $b.Status, $b.Cmdlet, $b.Note) -InformationAction Continue
    }
}

# Emit the result objects so a caller can capture/pipe them.
$results
