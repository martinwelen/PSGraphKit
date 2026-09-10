#Requires -Version 7.4
<#
.SYNOPSIS
    Live validation protocol for PSGraphKit's WRITE cmdlets, against disposable objects.

.DESCRIPTION
    The unit tests mock the HTTP seam, so they prove the module builds the right request — they
    cannot prove Graph accepts it, and they cannot see tenant preconditions (Temporary Access Pass
    enabled in the authentication methods policy, Windows LAPS deployed, the signed-in admin's role
    outranking the target). This protocol closes that gap.

    Every scenario follows the same shape:

      1. Create a disposable object, named '<Prefix>-<runstamp>-...' so it is unmistakably ours.
      2. Run the cmdlet with -WhatIf and assert NOTHING changed.
      3. Run it for real.
      4. Verify the resulting SERVER STATE, not the return code — read the object back and check the
         property actually moved. A 2xx that changed nothing is the failure this catches.
      5. Tear down in a finally block, so a mid-run failure still cleans up.

    DESTRUCTIVE, BY DESIGN. It resets passwords, issues credentials that satisfy MFA, and deletes
    objects. Point it at a dev tenant, never at one that matters. It only ever touches objects it
    created itself: every target is matched against the run prefix before any write, and a scenario
    whose setup did not complete is skipped rather than guessed at.

    Microsoft Graph auth is interactive and does not survive across processes, so run this in YOUR
    OWN terminal:

        Connect-GkGraph -ForCommand Reset-GkUserPassword, New-GkTemporaryAccessPass, `
                                    Restore-GkDeletedObject, Add-GkGroupMember
        ./build/Invoke-GkWriteProtocol.ps1

    Run -ScopePlan first to see the exact least-privilege connect line per scenario. Running each
    scenario under only its declared scope is what validates the scope map against Graph rather than
    against the documentation — see DESIGN.md section 7.

.PARAMETER Login
    Connect interactively before running, with the union of scopes every scenario needs.

.PARAMETER Prefix
    Name prefix for disposable objects. Defaults to 'gktest'. Everything created carries it, and the
    orphan sweep keys on it.

.PARAMETER Only
    Run just this scenario (by name). Use with a least-privilege connection to test one cmdlet's
    declared scope in isolation.

.PARAMETER LapsDeviceId
    A device that has a Windows LAPS credential backed up. Without it the LAPS scenario runs in list
    mode and reports SKIPPED rather than passing on no evidence.

.PARAMETER CleanOrphans
    Delete every object matching the prefix from earlier runs, then exit. Use after a run that died
    before its teardown.

.PARAMETER ScopePlan
    Print the least-privilege connect line for each scenario and exit. Makes no changes.

.PARAMETER ReportPath
    Write a timestamped markdown report here. Defaults to docs/protocol-runs/.

.EXAMPLE
    ./build/Invoke-GkWriteProtocol.ps1 -ScopePlan

.EXAMPLE
    ./build/Invoke-GkWriteProtocol.ps1 -Login

.EXAMPLE
    Connect-GkGraph -ForCommand Reset-GkUserPassword
    ./build/Invoke-GkWriteProtocol.ps1 -Only ResetPassword

.EXAMPLE
    ./build/Invoke-GkWriteProtocol.ps1 -CleanOrphans
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
# LapsDeviceId is read inside a scenario scriptblock, which the analyzer cannot follow.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'LapsDeviceId',
    Justification = 'Consumed inside the LapsRead scenario scriptblock.')]
param(
    [switch] $Login,
    [string] $Prefix = 'gktest',
    [string] $Only,
    [string] $LapsDeviceId,
    [switch] $CleanOrphans,
    [switch] $ScopePlan,
    [string] $ReportPath
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

# Scenarios, and the scope each one needs on its own. The scope list is what makes this a test OF
# the scope map: connect with exactly these and the scenario must still pass.
$scenarioScopes = [ordered]@{
    ResetPassword    = @('User-PasswordProfile.ReadWrite.All', 'User.ReadWrite.All')
    # The verification step reads the pass back through Get-GkUserAuthMethod, which needs a read
    # scope of its own — issuing a TAP does not confer the right to enumerate auth methods.
    TemporaryAccess  = @('UserAuthMethod-TAP.ReadWrite.All', 'User.ReadWrite.All', 'UserAuthenticationMethod.Read.All')
    DeleteRestore    = @('User.DeleteRestore.All', 'User.ReadWrite.All')
    DisableUser      = @('User.EnableDisableAccount.All', 'User.Read.All', 'User.ReadWrite.All')
    GroupMembership  = @('GroupMember.ReadWrite.All', 'Group.ReadWrite.All')
    GroupOwner       = @('Group.ReadWrite.All')
    AppCredential    = @('Application.ReadWrite.All')
    RevokeSession    = @('User.RevokeSessions.All', 'User.ReadWrite.All')
    # Staging a licence needs a write on the user and a read of subscribedSkus; the removal itself
    # only needs the licence scope.
    UserLicense      = @('LicenseAssignment.ReadWrite.All', 'User.ReadWrite.All', 'Organization.Read.All')
    GuestInvitation  = @('User.Invite.All', 'User.ReadWrite.All')
    StaleGuest       = @('User.Invite.All', 'User.EnableDisableAccount.All', 'User.Read.All', 'User.ReadWrite.All')
    StaleDevice      = @('Device.ReadWrite.All')
    # RoleManagement.ReadWrite.Directory covers both staging the assignment and removing it.
    AdminRole        = @('RoleManagement.ReadWrite.Directory', 'User.ReadWrite.All')
    ConsentGrant     = @('DelegatedPermissionGrant.ReadWrite.All', 'Application.ReadWrite.All')
    LapsRead         = @('DeviceLocalCredential.Read.All')
}

if ($ScopePlan) {
    Write-Information 'Least-privilege connect line per scenario:' -InformationAction Continue
    Write-Information '' -InformationAction Continue
    foreach ($name in $scenarioScopes.Keys) {
        Write-Information ("  {0,-16} Connect-MgGraph -Scopes {1}" -f $name, ($scenarioScopes[$name] -join ',')) -InformationAction Continue
    }
    Write-Information '' -InformationAction Continue
    Write-Information 'Then: ./build/Invoke-GkWriteProtocol.ps1 -Only <scenario>' -InformationAction Continue
    return
}

if ($Login) {
    $all = @($scenarioScopes.Values | ForEach-Object { $_ } | Select-Object -Unique)
    Write-Information "Connecting (interactive) with $($all.Count) scopes..." -InformationAction Continue
    Connect-MgGraph -Scopes $all -NoWelcome | Out-Null
}

$ctx = Get-MgContext
if (-not $ctx) { throw "Not connected. Run Connect-GkGraph first, or pass -Login." }
Write-Information "Connected as $($ctx.Account) ($($ctx.AuthType)) in tenant $($ctx.TenantId)." -InformationAction Continue

# The tenant's verified domain, needed to build a UPN for a disposable user.
$domain = (Invoke-MgGraphRequest -Method GET -Uri 'v1.0/organization?$select=verifiedDomains' -OutputType Hashtable).value[0].verifiedDomains |
    Where-Object { $_.isDefault } | Select-Object -First 1 -ExpandProperty name
if (-not $domain) { throw 'Could not determine the default verified domain.' }

$runStamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
$runPrefix = "$Prefix-$runStamp"

# --- Guard rails --------------------------------------------------------------------------------
# Nothing is written to an object whose name does not carry our prefix. A scenario that loses track
# of what it created fails loudly rather than acting on a real object.
function Assert-GkDisposable {
    param([Parameter(Mandatory)] [string] $Name, [Parameter(Mandatory)] [string] $What)
    if ($Name -notlike "$Prefix-*") {
        throw "Refusing to touch '$What': name '$Name' does not carry the disposable prefix '$Prefix-'."
    }
}

function New-GkDisposableUser {
    param([string] $Tag = 'user')
    $upn = "$runPrefix-$Tag@$domain"
    $body = @{
        accountEnabled    = $true
        displayName       = "$runPrefix-$Tag"
        mailNickname      = "$runPrefix-$Tag" -replace '[^a-zA-Z0-9]', ''
        userPrincipalName = $upn
        passwordProfile   = @{ password = ([guid]::NewGuid().ToString() + 'Aa1!'); forceChangePasswordNextSignIn = $false }
    }
    $u = Invoke-MgGraphRequest -Method POST -Uri 'v1.0/users' -Body $body -OutputType Hashtable
    return [pscustomobject]@{ Id = $u.id; Upn = $upn; DisplayName = $body.displayName }
}

function New-GkDisposableGroup {
    param([string] $Tag = 'group')
    $body = @{
        displayName     = "$runPrefix-$Tag"
        mailNickname    = "$runPrefix-$Tag" -replace '[^a-zA-Z0-9]', ''
        mailEnabled     = $false
        securityEnabled = $true
    }
    $g = Invoke-MgGraphRequest -Method POST -Uri 'v1.0/groups' -Body $body -OutputType Hashtable
    return [pscustomobject]@{ Id = $g.id; DisplayName = $body.displayName }
}

function New-GkDisposableApp {
    param([string] $Tag = 'app')
    $body = @{ displayName = "$runPrefix-$Tag" }
    $a = Invoke-MgGraphRequest -Method POST -Uri 'v1.0/applications' -Body $body -OutputType Hashtable
    return [pscustomobject]@{ Id = $a.id; DisplayName = $body.displayName }
}

function Remove-GkDisposable {
    param([string] $Collection, [string] $Id, [string] $Name)
    if (-not $Id) { return }
    if ($Name) { Assert-GkDisposable -Name $Name -What "$Collection/$Id" }
    try { Invoke-MgGraphRequest -Method DELETE -Uri "v1.0/$Collection/$Id" | Out-Null }
    catch { Write-Warning "Teardown: could not delete $Collection/$Id - $($_.Exception.Message)" }
}

# Read a single property straight from Graph, bypassing the module — the verification step must not
# depend on the code under test.
function Get-GkRawProperty {
    param([string] $Uri, [string] $Property)
    try {
        $r = Invoke-MgGraphRequest -Method GET -Uri $Uri -OutputType Hashtable
        return $r[$Property]
    }
    catch { return $null }
}

# Directory reads are eventually consistent: two GETs seconds apart can hit different replicas and
# report different values for the same property. Observed on a freshly written user, reading
# accountEnabled back four times: False, False, True, False. A single read-back therefore proves
# nothing — it fails runs that are actually correct, and the failure point moves between runs. Every
# verification goes through one of the two helpers below instead of reading once after a sleep.

function Wait-GkUntil {
    <#
    .SYNOPSIS
        Poll until the condition holds, or give up at the timeout. Returns $true/$false.
    .DESCRIPTION
        For asserting that a write DID take effect. The value we wrote is the one that eventually
        wins on every replica, so the first read that reports it is proof enough; a replica still
        serving the old value is lag, not a failure.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingEmptyCatchBlock', '',
        Justification = 'A read that throws is exactly the transient this polls through; surfacing it would defeat the retry.')]
    param(
        [Parameter(Mandatory)] [scriptblock] $Condition,
        [int] $TimeoutSeconds = 90,
        [int] $IntervalSeconds = 3
    )
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ($true) {
        try { if (& $Condition) { return $true } } catch { }
        if ((Get-Date) -ge $deadline) { return $false }
        Start-Sleep -Seconds $IntervalSeconds
    }
}

function Test-GkStable {
    <#
    .SYNOPSIS
        Require the condition to hold on several consecutive reads. Returns $true/$false.
    .DESCRIPTION
        For asserting that a write did NOT happen (-WhatIf). "Nothing changed" cannot be waited for
        — waiting only ever makes a false negative more likely — so sample repeatedly and demand
        agreement. One stale replica disagreeing is enough to fail, which is the safe direction: a
        -WhatIf that actually wrote something must never pass.
    #>
    param(
        [Parameter(Mandatory)] [scriptblock] $Condition,
        [int] $Samples = 3,
        [int] $IntervalSeconds = 2
    )
    for ($i = 0; $i -lt $Samples; $i++) {
        try { if (-not (& $Condition)) { return $false } } catch { return $false }
        if ($i -lt $Samples - 1) { Start-Sleep -Seconds $IntervalSeconds }
    }
    return $true
}

function Get-GkRawCollectionCount {
    <#
    .SYNOPSIS
        Count a collection-valued property, letting a failed read throw instead of counting as one.
    .DESCRIPTION
        @($null).Count is 1 in PowerShell, so combining Get-GkRawProperty (which returns $null when
        the read fails) with @(...).Count makes a transient 404 indistinguishable from "one element
        present" — which silently flips a -WhatIf assertion from pass to fail. Throwing instead is
        the safe shape here: every caller is Wait-GkUntil or Test-GkNoChange, both of which treat a
        throw as "not observed" and retry.
    #>
    param([Parameter(Mandatory)] [string] $Uri, [Parameter(Mandatory)] [string] $Property)
    $r = Invoke-MgGraphRequest -Method GET -Uri $Uri -OutputType Hashtable
    return @($r[$Property] | Where-Object { $null -ne $_ }).Count
}

function Wait-GkFor {
    <#
    .SYNOPSIS
        Poll until the scriptblock produces a non-null value, and hand that value back.
    .DESCRIPTION
        Wait-GkUntil answers "did it happen yet", which is all a single assertion needs. When several
        assertions describe the SAME object, re-reading it once per assertion reintroduces the
        problem: each read can land on a different replica, so a shape that satisfied the wait can
        fail the very next check. Capture the snapshot that satisfied the wait and assert against it.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingEmptyCatchBlock', '',
        Justification = 'A read that throws is exactly the transient this polls through; surfacing it would defeat the retry.')]
    param(
        [Parameter(Mandatory)] [scriptblock] $Producer,
        [int] $TimeoutSeconds = 90,
        [int] $IntervalSeconds = 3
    )
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ($true) {
        try { $v = & $Producer; if ($null -ne $v) { return $v } } catch { }
        if ((Get-Date) -ge $deadline) { return $null }
        Start-Sleep -Seconds $IntervalSeconds
    }
}

function Test-GkNoChange {
    <#
    .SYNOPSIS
        Assert that a write did NOT happen, by watching for the written state and requiring that it
        never appears. Returns $true when nothing changed.
    .DESCRIPTION
        The obvious phrasing — "the old value is still there on every read" — fails whenever a
        replica transiently misses an object it should have, which says nothing about whether we
        wrote to it. Stated this way round, only actually observing the NEW state fails the check,
        which is precisely the thing -WhatIf must never produce.
    #>
    param(
        [Parameter(Mandatory)] [scriptblock] $WrittenState,
        [int] $WatchSeconds = 12,
        [int] $IntervalSeconds = 3
    )
    return -not (Wait-GkUntil -Condition $WrittenState -TimeoutSeconds $WatchSeconds -IntervalSeconds $IntervalSeconds)
}

function Wait-GkObjectReadable {
    <#
    .SYNOPSIS
        Block until a newly created object is readable, so a scenario never measures its own
        baseline against a replica that has not seen the object yet.
    #>
    param([Parameter(Mandatory)] [string] $Collection, [Parameter(Mandatory)] [string] $Id)
    # One successful read is not enough: it only proves the replica we happened to hit has the
    # object. The next call can still land on one that does not, which surfaces as a 404 in the
    # middle of an assertion. Require several consecutive reads so the object has propagated before
    # any scenario starts measuring.
    $ok = Wait-GkUntil -TimeoutSeconds 180 -Condition {
        Test-GkStable -Samples 3 -IntervalSeconds 1 -Condition {
            (Get-GkRawProperty -Uri "v1.0/$Collection/${Id}?`$select=id" -Property 'id') -eq $Id
        }
    }
    if (-not $ok) { throw "Precondition: $Collection/$Id never became consistently readable." }
}

# --- Orphan sweep -------------------------------------------------------------------------------
if ($CleanOrphans) {
    Write-Information "Sweeping objects matching '$Prefix-*'..." -InformationAction Continue
    $swept = 0
    foreach ($c in 'users', 'groups', 'applications', 'devices', 'servicePrincipals') {
        $filter = [uri]::EscapeDataString("startswith(displayName,'$Prefix-')")
        $items = (Invoke-MgGraphRequest -Method GET -Uri "v1.0/${c}?`$filter=$filter&`$select=id,displayName" -OutputType Hashtable).value
        foreach ($i in @($items)) {
            if ($PSCmdlet.ShouldProcess("$c/$($i.displayName)", 'Delete orphaned test object')) {
                Remove-GkDisposable -Collection $c -Id $i.id -Name $i.displayName
                $swept++
                Write-Information "  deleted $c/$($i.displayName)" -InformationAction Continue
            }
        }
    }
    Write-Information "Swept $swept object(s)." -InformationAction Continue
    return
}

# --- Scenario runner ----------------------------------------------------------------------------
$results = [System.Collections.Generic.List[object]]::new()

function Invoke-GkScenario {
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [scriptblock] $Body
    )
    if ($Only -and $Only -ne $Name) { return }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $checks = [System.Collections.Generic.List[string]]::new()
    $status = 'PASS'
    $note = ''
    try {
        # The scenario reports its own assertions by adding to $checks; throwing means FAIL.
        & $Body $checks
    }
    catch {
        $status = 'FAIL'
        $note = $_.Exception.Message.Split([char]10)[0]
    }
    $sw.Stop()

    if ($status -eq 'PASS' -and $checks.Count -eq 0) {
        $status = 'SKIPPED'
        $note = 'no assertions ran — precondition missing'
    }
    elseif ($status -eq 'PASS') {
        $skips = @($checks | Where-Object { $_ -like 'SKIP:*' })
        if ($skips.Count -eq $checks.Count) { $status = 'SKIPPED'; $note = ($skips[0] -replace '^SKIP:\s*', '') }
    }

    $row = [pscustomobject]@{
        Scenario = $Name
        Status   = $status
        Checks   = $checks.Count
        Seconds  = [math]::Round($sw.Elapsed.TotalSeconds, 1)
        Note     = $note
        Detail   = ($checks -join ' | ')
    }
    $results.Add($row)
    Write-Information ("  {0,-8} {1,-17} {2,2} check(s) {3,6}s  {4}" -f $row.Status, $row.Scenario, $row.Checks, $row.Seconds, $row.Note) -InformationAction Continue
}

function Assert-GkTrue {
    param([System.Collections.Generic.List[string]] $Checks, [bool] $Condition, [string] $Description)
    if (-not $Condition) { throw "Assertion failed: $Description" }
    $Checks.Add($Description)
}

Write-Information '' -InformationAction Continue
Write-Information "Run prefix: $runPrefix   domain: $domain" -InformationAction Continue
Write-Information 'Scenarios (each creates its own disposable objects and tears them down):' -InformationAction Continue

# --- 1. Password reset --------------------------------------------------------------------------
Invoke-GkScenario -Name 'ResetPassword' -Body {
    param($checks)
    $user = New-GkDisposableUser -Tag 'pwd'
    try {
        Wait-GkObjectReadable -Collection 'users' -Id $user.Id
        $uri = "v1.0/users/$($user.Id)?`$select=lastPasswordChangeDateTime"
        $before = Get-GkRawProperty -Uri $uri -Property 'lastPasswordChangeDateTime'

        Reset-GkUserPassword -UserId $user.Id -WhatIf | Out-Null
        Assert-GkTrue $checks (Test-GkNoChange { (Get-GkRawProperty -Uri $uri -Property 'lastPasswordChangeDateTime') -ne $before }) '-WhatIf changed nothing'

        $r = Reset-GkUserPassword -UserId $user.Id -Confirm:$false
        Assert-GkTrue $checks ($r.Outcome -eq 'Reset') 'reset reported success'
        Assert-GkTrue $checks (-not [string]::IsNullOrWhiteSpace($r.Password)) 'a password was returned'
        Assert-GkTrue $checks ($r.Password.Length -ge 20) 'the generated password is full length'

        Assert-GkTrue $checks (Wait-GkUntil { (Get-GkRawProperty -Uri $uri -Property 'lastPasswordChangeDateTime') -ne $before }) 'lastPasswordChangeDateTime advanced on the server'
    }
    finally { Remove-GkDisposable -Collection 'users' -Id $user.Id -Name $user.DisplayName }
}

# --- 2. Temporary Access Pass -------------------------------------------------------------------
Invoke-GkScenario -Name 'TemporaryAccess' -Body {
    param($checks)
    $user = New-GkDisposableUser -Tag 'tap'
    try {
        Wait-GkObjectReadable -Collection 'users' -Id $user.Id
        New-GkTemporaryAccessPass -UserId $user.Id -WhatIf | Out-Null
        Assert-GkTrue $checks (Test-GkNoChange { @(Get-GkUserAuthMethod -UserId $user.Id -MethodType TemporaryAccessPass).Count -ge 1 }) '-WhatIf issued no pass'

        $r = New-GkTemporaryAccessPass -UserId $user.Id -LifetimeInMinutes 60 -Confirm:$false
        if ($r.Outcome -ne 'Created') {
            # A tenant with TAP disabled in the auth methods policy cannot run this scenario.
            $checks.Add("SKIP: TAP not issued — $($r.Error)")
            return
        }
        Assert-GkTrue $checks (-not [string]::IsNullOrWhiteSpace($r.TemporaryAccessPass)) 'a passcode was returned'
        Assert-GkTrue $checks ($r.IsUsableOnce) 'defaults to single-use'

        Assert-GkTrue $checks (Wait-GkUntil { @(Get-GkUserAuthMethod -UserId $user.Id -MethodType TemporaryAccessPass).Count -eq 1 }) 'the pass is registered on the account'

        # Graph does not reject a second concurrent pass — verified raw against the API, both POSTs
        # return a new id and the account is then left with exactly one pass, so the second
        # supersedes the first. Assert that invariant instead of a particular Graph status code: what
        # the caller depends on is never ending up with two live passes, and pinning the protocol to
        # a 400 makes it a test of Microsoft's error handling rather than of this module.
        $second = New-GkTemporaryAccessPass -UserId $user.Id -Confirm:$false -WarningAction SilentlyContinue
        Assert-GkTrue $checks ($second.Outcome -in @('Created', 'Failed')) 'a second issue is reported, not swallowed'
        Assert-GkTrue $checks (Wait-GkUntil { @(Get-GkUserAuthMethod -UserId $user.Id -MethodType TemporaryAccessPass).Count -eq 1 }) 'the account is left with exactly one pass'
    }
    finally { Remove-GkDisposable -Collection 'users' -Id $user.Id -Name $user.DisplayName }
}

# --- 3. Delete and restore round trip -----------------------------------------------------------
Invoke-GkScenario -Name 'DeleteRestore' -Body {
    param($checks)
    $user = New-GkDisposableUser -Tag 'restore'
    $restored = $false
    try {
        Wait-GkObjectReadable -Collection 'users' -Id $user.Id
        Assert-GkDisposable -Name $user.DisplayName -What "users/$($user.Id)"
        # The delete itself can 404 on a replica that has not seen the user yet, so retry it rather
        # than reporting a setup failure as a scenario failure.
        $gone = Wait-GkUntil { try { Invoke-MgGraphRequest -Method DELETE -Uri "v1.0/users/$($user.Id)" | Out-Null; $true } catch { $false } }
        if (-not $gone) { throw "Precondition: could not delete users/$($user.Id) for the restore round trip." }

        $deleted = Wait-GkFor { $d = @(Get-GkDeletedItem -Type User | Where-Object Id -eq $user.Id); if ($d.Count -eq 1) { $d[0] } }
        Assert-GkTrue $checks ($null -ne $deleted) 'the deleted user appears in deletedItems'
        Assert-GkTrue $checks ($deleted.DaysUntilPurge -gt 25) 'the restore window is reported'

        Restore-GkDeletedObject -Id $user.Id -Type User -WhatIf | Out-Null
        # Not "the user is not live": a soft-deleted user still answers on /users/{id} for a while,
        # so that would be true without any restore. Wait for it to be present in deletedItems
        # instead — had -WhatIf actually restored it, it would never appear there again.
        Assert-GkTrue $checks (Wait-GkUntil { @(Get-GkDeletedItem -Type User | Where-Object Id -eq $user.Id).Count -eq 1 }) '-WhatIf restored nothing'

        # The restore endpoint 404s on a replica that has not caught up ('Unable to read the
        # company information'), so wait for the deleted item to be consistently visible before
        # calling the cmdlet under test — rather than retrying the cmdlet, which would mask a real
        # failure to restore.
        $null = Wait-GkUntil { Test-GkStable -Samples 3 -IntervalSeconds 2 -Condition { @(Get-GkDeletedItem -Type User | Where-Object Id -eq $user.Id).Count -eq 1 } }
        # Graph intermittently 404s this endpoint on a replica that has not caught up ("Unable to
        # read the company information from the directory") even when the deleted item is by then
        # consistently listed. That is a transient in the service, not in the cmdlet, so retry within
        # a bounded window — a restore that never succeeds still fails the scenario.
        $r = Wait-GkFor -TimeoutSeconds 120 -Producer {
            $attempt = Restore-GkDeletedObject -Id $user.Id -Type User -Confirm:$false -WarningAction SilentlyContinue
            if ($attempt.Outcome -eq 'Restored') { $attempt }
        }
        Assert-GkTrue $checks ($null -ne $r) 'restore reported success'
        $restored = $true

        Assert-GkTrue $checks (Wait-GkUntil { (Get-GkRawProperty -Uri "v1.0/users/$($user.Id)?`$select=id" -Property 'id') -eq $user.Id }) 'the user is live in the directory again'
    }
    finally {
        # If the restore succeeded the object is live again and must be deleted; if it never
        # restored it is already in the recycle bin and will purge on its own.
        if ($restored) { Remove-GkDisposable -Collection 'users' -Id $user.Id -Name $user.DisplayName }
    }
}

# --- 4. Disable a user --------------------------------------------------------------------------
Invoke-GkScenario -Name 'DisableUser' -Body {
    param($checks)
    $user = New-GkDisposableUser -Tag 'disable'
    try {
        Wait-GkObjectReadable -Collection 'users' -Id $user.Id
        $uri = "v1.0/users/$($user.Id)?`$select=accountEnabled"
        Disable-GkStaleUser -UserId $user.Id -WhatIf | Out-Null
        Assert-GkTrue $checks (Test-GkNoChange { (Get-GkRawProperty -Uri $uri -Property 'accountEnabled') -eq $false }) '-WhatIf left the account enabled'

        $r = Disable-GkStaleUser -UserId $user.Id -Confirm:$false
        Assert-GkTrue $checks ($r.Outcome -eq 'Disabled') 'disable reported success'
        Assert-GkTrue $checks (Wait-GkUntil { (Get-GkRawProperty -Uri $uri -Property 'accountEnabled') -eq $false }) 'accountEnabled is false on the server'
    }
    finally { Remove-GkDisposable -Collection 'users' -Id $user.Id -Name $user.DisplayName }
}

# --- 5. Group membership add / remove -----------------------------------------------------------
Invoke-GkScenario -Name 'GroupMembership' -Body {
    param($checks)
    $group = New-GkDisposableGroup -Tag 'members'
    $user = New-GkDisposableUser -Tag 'member'
    try {
        Wait-GkObjectReadable -Collection 'groups' -Id $group.Id
        Wait-GkObjectReadable -Collection 'users' -Id $user.Id
        Add-GkGroupMember -GroupId $group.Id -MemberId $user.Id -WhatIf | Out-Null
        Assert-GkTrue $checks (Test-GkNoChange { @(Get-GkGroupMember -GroupId $group.Id).Count -ge 1 }) '-WhatIf added nobody'

        Add-GkGroupMember -GroupId $group.Id -MemberId $user.Id -Confirm:$false | Out-Null
        $member = Wait-GkFor { $m = @(Get-GkGroupMember -GroupId $group.Id); if ($m.Count -eq 1) { $m[0] } }
        Assert-GkTrue $checks ($null -ne $member) 'the member was added'
        Assert-GkTrue $checks ($member.MemberType -eq 'User') 'the member type resolves to User'
        Assert-GkTrue $checks ($member.Id -eq $user.Id) 'the right object was added'

        Remove-GkGroupMember -GroupId $group.Id -MemberId $user.Id -Confirm:$false | Out-Null
        Assert-GkTrue $checks (Wait-GkUntil { @(Get-GkGroupMember -GroupId $group.Id).Count -eq 0 }) 'the member was removed'
    }
    finally {
        Remove-GkDisposable -Collection 'users' -Id $user.Id -Name $user.DisplayName
        Remove-GkDisposable -Collection 'groups' -Id $group.Id -Name $group.DisplayName
    }
}

# --- 6. Group owner -----------------------------------------------------------------------------
Invoke-GkScenario -Name 'GroupOwner' -Body {
    param($checks)
    $group = New-GkDisposableGroup -Tag 'owners'
    $user = New-GkDisposableUser -Tag 'owner'
    try {
        Wait-GkObjectReadable -Collection 'groups' -Id $group.Id
        Wait-GkObjectReadable -Collection 'users' -Id $user.Id
        $ownerUri = "v1.0/groups/$($group.Id)/owners?`$select=id"
        Set-GkGroupOwner -GroupId $group.Id -OwnerId $user.Id -WhatIf | Out-Null
        Assert-GkTrue $checks (Test-GkNoChange { @((Invoke-MgGraphRequest -Method GET -Uri $ownerUri -OutputType Hashtable).value).Count -ge 1 }) '-WhatIf set no owner'

        Set-GkGroupOwner -GroupId $group.Id -OwnerId $user.Id -Confirm:$false | Out-Null
        $owner = Wait-GkFor {
            $o = @((Invoke-MgGraphRequest -Method GET -Uri $ownerUri -OutputType Hashtable).value)
            if ($o.Count -eq 1) { $o[0] }
        }
        Assert-GkTrue $checks ($null -ne $owner) 'the owner was set'
        Assert-GkTrue $checks ($owner.id -eq $user.Id) 'the right principal owns the group'
    }
    finally {
        Remove-GkDisposable -Collection 'users' -Id $user.Id -Name $user.DisplayName
        Remove-GkDisposable -Collection 'groups' -Id $group.Id -Name $group.DisplayName
    }
}

# --- 7. Application credential add / remove -----------------------------------------------------
Invoke-GkScenario -Name 'AppCredential' -Body {
    param($checks)
    $app = New-GkDisposableApp -Tag 'cred'
    try {
        Wait-GkObjectReadable -Collection 'applications' -Id $app.Id
        $credUri = "v1.0/applications/$($app.Id)?`$select=passwordCredentials"
        Reset-GkAppCredential -ApplicationId $app.Id -WhatIf | Out-Null
        Assert-GkTrue $checks (Test-GkNoChange { (Get-GkRawCollectionCount -Uri $credUri -Property 'passwordCredentials') -ge 1 }) '-WhatIf added no secret'

        $r = Reset-GkAppCredential -ApplicationId $app.Id -Confirm:$false
        Assert-GkTrue $checks (-not [string]::IsNullOrWhiteSpace($r.SecretText)) 'a secret was returned'
        Assert-GkTrue $checks (-not [string]::IsNullOrWhiteSpace($r.KeyId)) 'the keyId was returned'

        Assert-GkTrue $checks (Wait-GkUntil { (Get-GkRawCollectionCount -Uri $credUri -Property 'passwordCredentials') -eq 1 }) 'the secret exists on the application'

        # removePassword rejects a keyId the replica serving it has not seen yet ("No password
        # credential found with keyId as ..."), so the removal is retried rather than issued once.
        # The condition is the server state, not the call's return, so a removal that never takes
        # effect still fails.
        Assert-GkTrue $checks (Wait-GkUntil -TimeoutSeconds 150 -Condition {
            if ((Get-GkRawCollectionCount -Uri $credUri -Property 'passwordCredentials') -eq 0) { return $true }
            Reset-GkAppCredential -ApplicationId $app.Id -RemoveKeyId $r.KeyId -Confirm:$false -WarningAction SilentlyContinue | Out-Null
            (Get-GkRawCollectionCount -Uri $credUri -Property 'passwordCredentials') -eq 0
        }) 'the secret was removed'
    }
    finally { Remove-GkDisposable -Collection 'applications' -Id $app.Id -Name $app.DisplayName }
}

# --- 8. Revoke sign-in sessions -----------------------------------------------------------------
Invoke-GkScenario -Name 'RevokeSession' -Body {
    param($checks)
    $user = New-GkDisposableUser -Tag 'revoke'
    try {
        Wait-GkObjectReadable -Collection 'users' -Id $user.Id
        $uri = "v1.0/users/$($user.Id)?`$select=signInSessionsValidFromDateTime"
        $before = Get-GkRawProperty -Uri $uri -Property 'signInSessionsValidFromDateTime'

        Revoke-GkUserSession -UserId $user.Id -WhatIf | Out-Null
        Assert-GkTrue $checks (Test-GkNoChange { (Get-GkRawProperty -Uri $uri -Property 'signInSessionsValidFromDateTime') -ne $before }) '-WhatIf revoked nothing'

        $r = Revoke-GkUserSession -UserId $user.Id -Confirm:$false
        Assert-GkTrue $checks ($r.Outcome -eq 'Revoked') 'revoke reported success'
        # This is the only externally visible trace of a revocation: every token issued before this
        # stamp is refused. If it does not move, nothing was actually revoked.
        Assert-GkTrue $checks (Wait-GkUntil { (Get-GkRawProperty -Uri $uri -Property 'signInSessionsValidFromDateTime') -ne $before }) 'signInSessionsValidFromDateTime advanced on the server'
    }
    finally { Remove-GkDisposable -Collection 'users' -Id $user.Id -Name $user.DisplayName }
}

# --- 9. Remove a license ------------------------------------------------------------------------
Invoke-GkScenario -Name 'UserLicense' -Body {
    param($checks)
    $user = New-GkDisposableUser -Tag 'lic'
    try {
        Wait-GkObjectReadable -Collection 'users' -Id $user.Id

        # A licence cannot be assigned without a usage location, and needs a SKU with a free seat.
        Invoke-MgGraphRequest -Method PATCH -Uri "v1.0/users/$($user.Id)" -Body @{ usageLocation = 'SE' } | Out-Null
        $sku = @((Invoke-MgGraphRequest -Method GET -Uri 'v1.0/subscribedSkus' -OutputType Hashtable).value |
            Where-Object { $_.prepaidUnits.enabled -gt $_.consumedUnits }) | Select-Object -First 1
        if (-not $sku) { $checks.Add('SKIP: no SKU with a free seat in this tenant'); return }

        $assigned = Wait-GkUntil -TimeoutSeconds 120 -Condition {
            try {
                Invoke-MgGraphRequest -Method POST -Uri "v1.0/users/$($user.Id)/assignLicense" `
                    -Body @{ addLicenses = @(@{ skuId = $sku.skuId; disabledPlans = @() }); removeLicenses = @() } | Out-Null
                $true
            } catch { $false }
        }
        if (-not $assigned) { $checks.Add('SKIP: could not assign a licence to stage the scenario'); return }

        $licUri = "v1.0/users/$($user.Id)?`$select=assignedLicenses"
        Assert-GkTrue $checks (Wait-GkUntil -TimeoutSeconds 180 -Condition { Test-GkStable -Samples 3 -IntervalSeconds 2 -Condition { (Get-GkRawCollectionCount -Uri $licUri -Property 'assignedLicenses') -eq 1 } }) 'the licence was staged'

        Remove-GkUserLicense -UserId $user.Id -SkuId $sku.skuId -WhatIf | Out-Null
        Assert-GkTrue $checks (Wait-GkUntil { (Get-GkRawCollectionCount -Uri $licUri -Property 'assignedLicenses') -eq 1 }) '-WhatIf removed no licence'

        $r = Remove-GkUserLicense -UserId $user.Id -SkuId $sku.skuId -Confirm:$false
        Assert-GkTrue $checks ($r.Outcome -eq 'Removed') 'removal reported success'
        Assert-GkTrue $checks (Wait-GkUntil { (Get-GkRawCollectionCount -Uri $licUri -Property 'assignedLicenses') -eq 0 }) 'the licence is gone from the server'
    }
    finally { Remove-GkDisposable -Collection 'users' -Id $user.Id -Name $user.DisplayName }
}

# --- 10. Guest invitation -----------------------------------------------------------------------
# -SendInvitationMessage is deliberately never passed: the protocol must not send mail to anyone.
# The address is at example.com, reserved by RFC 2606 and unroutable, so even a mistake goes nowhere.
Invoke-GkScenario -Name 'GuestInvitation' -Body {
    param($checks)
    $invited = $null
    try {
        $mail = "$runPrefix-guest@example.com"
        New-GkGuestInvitation -EmailAddress $mail -WhatIf | Out-Null
        Assert-GkTrue $checks (Test-GkNoChange { @(Invoke-MgGraphRequest -Method GET -Uri "v1.0/users?`$filter=mail eq '$mail'" -OutputType Hashtable).value.Count -ge 1 }) '-WhatIf invited nobody'

        $r = New-GkGuestInvitation -EmailAddress $mail -Confirm:$false
        if ($r.Outcome -ne 'Invited') {
            # A tenant can forbid B2B outright ("Guest invitations not allowed for your company"),
            # which no amount of permission fixes. That is a tenant capability, not a defect, so
            # report it as unproven rather than failed — the same treatment as LapsRead.
            # Drop the -WhatIf check first: the runner only reports SKIPPED when EVERY check is a
            # SKIP, so leaving a real check alongside would report PASS for a scenario that proved
            # nothing about inviting anyone.
            $checks.Clear()
            $checks.Add("SKIP: the tenant does not allow guest invitations — $($r.Error)")
            return
        }
        Assert-GkTrue $checks (-not [string]::IsNullOrWhiteSpace($r.InvitedUserId)) 'the created guest id was returned'
        $invited = $r.InvitedUserId

        $guest = Wait-GkFor { $g = Get-GkRawProperty -Uri "v1.0/users/$invited`?`$select=id,userType" -Property 'userType'; if ($g) { $g } }
        Assert-GkTrue $checks ($guest -eq 'Guest') 'the created object is a Guest'
    }
    finally {
        if ($invited) { try { Invoke-MgGraphRequest -Method DELETE -Uri "v1.0/users/$invited" | Out-Null } catch { Write-Warning "Teardown: could not delete guest $invited" } }
    }
}

# --- 11. Stale guest: disable, then delete ------------------------------------------------------
Invoke-GkScenario -Name 'StaleGuest' -Body {
    param($checks)
    $invited = $null
    try {
        $mail = "$runPrefix-stale@example.com"
        $inv = New-GkGuestInvitation -EmailAddress $mail -Confirm:$false
        if ($inv.Outcome -ne 'Invited') { $checks.Add("SKIP: could not stage a guest — $($inv.Error)"); return }
        $invited = $inv.InvitedUserId
        Wait-GkObjectReadable -Collection 'users' -Id $invited
        $uri = "v1.0/users/$invited`?`$select=accountEnabled"

        Remove-GkStaleGuest -UserId $invited -WhatIf | Out-Null
        Assert-GkTrue $checks (Test-GkNoChange { (Get-GkRawProperty -Uri $uri -Property 'accountEnabled') -eq $false }) '-WhatIf left the guest enabled'

        $r = Remove-GkStaleGuest -UserId $invited -Confirm:$false
        Assert-GkTrue $checks ($r.Outcome -eq 'Disabled') 'disable reported success'
        Assert-GkTrue $checks (Wait-GkUntil { (Get-GkRawProperty -Uri $uri -Property 'accountEnabled') -eq $false }) 'the guest is disabled on the server'

        # -Delete is a separate capability group in the scope map, so exercise it too.
        $d = Remove-GkStaleGuest -UserId $invited -Delete -Confirm:$false
        Assert-GkTrue $checks ($d.Outcome -eq 'Deleted') 'delete reported success'
        Assert-GkTrue $checks (Wait-GkUntil { @(Get-GkDeletedItem -Type User | Where-Object Id -eq $invited).Count -eq 1 }) 'the guest is in the recycle bin'
        $invited = $null   # already deleted; teardown would only log a 404
    }
    finally {
        if ($invited) { try { Invoke-MgGraphRequest -Method DELETE -Uri "v1.0/users/$invited" | Out-Null } catch { Write-Warning "Teardown: could not delete guest $invited" } }
    }
}

# --- 12. Stale device ---------------------------------------------------------------------------
Invoke-GkScenario -Name 'StaleDevice' -Body {
    param($checks)
    $deviceId = $null
    try {
        $key = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("X509:<SHA1-TP-PUBKEY>$([guid]::NewGuid())"))
        $body = @{
            accountEnabled         = $true
            alternativeSecurityIds = @(@{ type = 2; key = $key })
            deviceId               = [guid]::NewGuid().ToString()
            displayName            = "$runPrefix-device"
            operatingSystem        = 'Windows'
            operatingSystemVersion = '10.0.19045'
            profileType            = 'RegisteredDevice'
        }
        try { $dev = Invoke-MgGraphRequest -Method POST -Uri 'v1.0/devices' -Body $body -OutputType Hashtable }
        catch { $checks.Add("SKIP: this tenant will not accept a synthetic device object, and a real Entra-joined device cannot be staged from Graph — $($_.Exception.Message.Split([char]10)[0])"); return }
        $deviceId = $dev.id
        Wait-GkObjectReadable -Collection 'devices' -Id $deviceId
        $uri = "v1.0/devices/$deviceId`?`$select=accountEnabled"

        Disable-GkStaleDevice -Id $deviceId -WhatIf | Out-Null
        Assert-GkTrue $checks (Test-GkNoChange { (Get-GkRawProperty -Uri $uri -Property 'accountEnabled') -eq $false }) '-WhatIf left the device enabled'

        $r = Disable-GkStaleDevice -Id $deviceId -Confirm:$false
        Assert-GkTrue $checks ($r.Outcome -eq 'Disabled') 'disable reported success'
        Assert-GkTrue $checks (Wait-GkUntil { (Get-GkRawProperty -Uri $uri -Property 'accountEnabled') -eq $false }) 'the device is disabled on the server'
    }
    finally {
        if ($deviceId) { Remove-GkDisposable -Collection 'devices' -Id $deviceId -Name "$runPrefix-device" }
    }
}

# --- 13. Admin role assignment ------------------------------------------------------------------
Invoke-GkScenario -Name 'AdminRole' -Body {
    param($checks)
    $user = New-GkDisposableUser -Tag 'role'
    $assignmentId = $null
    try {
        Wait-GkObjectReadable -Collection 'users' -Id $user.Id
        # Directory Readers: the least consequential built-in role that can still be assigned.
        $roleDefId = '88d8e3e3-8f55-4a1e-953a-9b9898b8876b'
        $assign = Wait-GkFor -TimeoutSeconds 120 -Producer {
            try {
                Invoke-MgGraphRequest -Method POST -Uri 'v1.0/roleManagement/directory/roleAssignments' `
                    -Body @{ principalId = $user.Id; roleDefinitionId = $roleDefId; directoryScopeId = '/' } -OutputType Hashtable
            } catch { $null }
        }
        if (-not $assign) { $checks.Add('SKIP: could not stage a role assignment'); return }
        $assignmentId = $assign.id
        $roleUri = "v1.0/roleManagement/directory/roleAssignments/$assignmentId"

        Remove-GkAdminRoleAssignment -AssignmentKind Active -AssignmentId $assignmentId -WhatIf | Out-Null
        # Proven by the assignment still being retrievable. Watching for its absence would fail on
        # any transient 404, because Get-GkRawProperty cannot tell 'deleted' from 'read failed'.
        Assert-GkTrue $checks (Wait-GkUntil { (Get-GkRawProperty -Uri $roleUri -Property 'id') -eq $assignmentId }) '-WhatIf removed no assignment'

        # Same transient as the restore endpoint: the DELETE can 404 on a replica that has not
        # seen the freshly staged assignment. Bounded retry — a removal that never succeeds still fails.
        $r = Wait-GkFor -TimeoutSeconds 120 -Producer {
            $a = Remove-GkAdminRoleAssignment -AssignmentKind Active -AssignmentId $assignmentId -Confirm:$false -WarningAction SilentlyContinue
            if ($a.Outcome -eq 'Removed') { $a }
        }
        Assert-GkTrue $checks ($null -ne $r) 'removal reported success'
        Assert-GkTrue $checks (Wait-GkUntil { $null -eq (Get-GkRawProperty -Uri $roleUri -Property 'id') }) 'the assignment is gone from the server'
        $assignmentId = $null
    }
    finally {
        if ($assignmentId) { try { Invoke-MgGraphRequest -Method DELETE -Uri "v1.0/roleManagement/directory/roleAssignments/$assignmentId" | Out-Null } catch { Write-Warning 'Teardown: could not remove the staged role assignment.' } }
        Remove-GkDisposable -Collection 'users' -Id $user.Id -Name $user.DisplayName
    }
}

# --- 14. Consent grant --------------------------------------------------------------------------
Invoke-GkScenario -Name 'ConsentGrant' -Body {
    param($checks)
    $app = New-GkDisposableApp -Tag 'consent'
    $grantId = $null
    $spId = $null
    try {
        Wait-GkObjectReadable -Collection 'applications' -Id $app.Id
        $appId = Get-GkRawProperty -Uri "v1.0/applications/$($app.Id)?`$select=appId" -Property 'appId'
        $sp = Wait-GkFor -TimeoutSeconds 120 -Producer {
            try { Invoke-MgGraphRequest -Method POST -Uri 'v1.0/servicePrincipals' -Body @{ appId = $appId } -OutputType Hashtable } catch { $null }
        }
        if (-not $sp) { $checks.Add('SKIP: could not stage a service principal'); return }
        $spId = $sp.id

        $graphSpId = @((Invoke-MgGraphRequest -Method GET -Uri "v1.0/servicePrincipals?`$filter=appId eq '00000003-0000-0000-c000-000000000000'" -OutputType Hashtable).value)[0].id
        $grant = Wait-GkFor -TimeoutSeconds 120 -Producer {
            try {
                Invoke-MgGraphRequest -Method POST -Uri 'v1.0/oauth2PermissionGrants' -OutputType Hashtable `
                    -Body @{ clientId = $sp.id; consentType = 'AllPrincipals'; resourceId = $graphSpId; scope = 'User.Read' }
            } catch { $null }
        }
        if (-not $grant) { $checks.Add('SKIP: could not stage a consent grant'); return }
        $grantId = $grant.id
        $grantUri = "v1.0/oauth2PermissionGrants/$grantId"

        Remove-GkConsentGrant -GrantId $grantId -WhatIf | Out-Null
        Assert-GkTrue $checks (Wait-GkUntil { (Get-GkRawProperty -Uri $grantUri -Property 'id') -eq $grantId }) '-WhatIf revoked nothing'

        $r = Wait-GkFor -TimeoutSeconds 120 -Producer {
            $a = Remove-GkConsentGrant -GrantId $grantId -Confirm:$false -WarningAction SilentlyContinue
            if ($a.Outcome -eq 'Revoked') { $a }
        }
        Assert-GkTrue $checks ($null -ne $r) 'revoke reported success'
        Assert-GkTrue $checks (Wait-GkUntil { $null -eq (Get-GkRawProperty -Uri $grantUri -Property 'id') }) 'the grant is gone from the server'
        $grantId = $null
    }
    finally {
        if ($grantId) { try { Invoke-MgGraphRequest -Method DELETE -Uri "v1.0/oauth2PermissionGrants/$grantId" | Out-Null } catch { Write-Warning 'Teardown: could not remove the staged consent grant.' } }
        # Deleting the application does NOT delete its service principal — they are separate
        # directory objects. Without this the scenario leaks one enterprise app per run.
        if ($spId) { Remove-GkDisposable -Collection 'servicePrincipals' -Id $spId -Name $app.DisplayName }
        Remove-GkDisposable -Collection 'applications' -Id $app.Id -Name $app.DisplayName
    }
}

# --- 15. LAPS read ------------------------------------------------------------------------------
# Purely a read, and it cannot be staged: a LAPS credential only exists if Windows LAPS is deployed
# and a real device has backed one up. Without -LapsDeviceId this reports SKIPPED, never PASS.
Invoke-GkScenario -Name 'LapsRead' -Body {
    param($checks)
    if (-not $LapsDeviceId) {
        $listed = @(Get-GkLapsPassword)
        $checks.Add("SKIP: no -LapsDeviceId given; $($listed.Count) device(s) have credentials")
        return
    }
    $r = @(Get-GkLapsPassword -DeviceId $LapsDeviceId)
    Assert-GkTrue $checks ($r.Count -ge 1) 'a credential was returned'
    Assert-GkTrue $checks (-not [string]::IsNullOrWhiteSpace($r[0].Password)) 'the password decoded to plain text'
    Assert-GkTrue $checks (-not [string]::IsNullOrWhiteSpace($r[0].AccountName)) 'the local account name is reported'
    Assert-GkTrue $checks ($r[0].IsCurrent) 'the current credential is returned first'
}

# --- Summary ------------------------------------------------------------------------------------
Write-Information '' -InformationAction Continue
$fail = @($results | Where-Object Status -eq 'FAIL')
$skip = @($results | Where-Object Status -eq 'SKIPPED')
$pass = @($results | Where-Object Status -eq 'PASS')
Write-Information ("Write protocol: {0} PASS, {1} SKIPPED, {2} FAIL (of {3})." -f $pass.Count, $skip.Count, $fail.Count, $results.Count) -InformationAction Continue

if ($fail.Count -gt 0) {
    Write-Information '' -InformationAction Continue
    Write-Information 'FAILURES — do not ship:' -InformationAction Continue
    foreach ($f in $fail) { Write-Information ("  {0}: {1}" -f $f.Scenario, $f.Note) -InformationAction Continue }
}

# --- Report -------------------------------------------------------------------------------------
if (-not $ReportPath) {
    $dir = Join-Path $PSScriptRoot '..' 'docs' 'protocol-runs'
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $ReportPath = Join-Path $dir "write-protocol-$runStamp.md"
}

$filterText = 'all'
if ($Only) { $filterText = '`' + $Only + '`' }

$lines = @(
    "# Write protocol run — $runStamp"
    ''
    "- Tenant: ``$($ctx.TenantId)``"
    "- Account: ``$($ctx.Account)`` ($($ctx.AuthType))"
    "- Module: $((Get-Module PSGraphKit).Version)"
    "- Scenario filter: $filterText"
    ''
    "**$($pass.Count) PASS, $($skip.Count) SKIPPED, $($fail.Count) FAIL**"
    ''
    '| Scenario | Status | Checks | Seconds | Note |'
    '|---|---|---|---|---|'
)
foreach ($r in $results) {
    $lines += "| $($r.Scenario) | $($r.Status) | $($r.Checks) | $($r.Seconds) | $($r.Note) |"
}
$lines += ''
$lines += '## Assertions'
$lines += ''
foreach ($r in $results) {
    $lines += "**$($r.Scenario)**"
    foreach ($d in ($r.Detail -split ' \| ')) { if ($d) { $lines += "- $d" } }
    $lines += ''
}
Set-Content -Path $ReportPath -Value $lines -Encoding utf8
Write-Information "Report: $ReportPath" -InformationAction Continue

$results
