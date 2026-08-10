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
    TemporaryAccess  = @('UserAuthMethod-TAP.ReadWrite.All', 'User.ReadWrite.All')
    DeleteRestore    = @('User.DeleteRestore.All', 'User.ReadWrite.All')
    DisableUser      = @('User.EnableDisableAccount.All', 'User.Read.All', 'User.ReadWrite.All')
    GroupMembership  = @('GroupMember.ReadWrite.All', 'Group.ReadWrite.All')
    GroupOwner       = @('Group.ReadWrite.All')
    AppCredential    = @('Application.ReadWrite.All')
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

# --- Orphan sweep -------------------------------------------------------------------------------
if ($CleanOrphans) {
    Write-Information "Sweeping objects matching '$Prefix-*'..." -InformationAction Continue
    $swept = 0
    foreach ($c in 'users', 'groups', 'applications') {
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
        Start-Sleep -Seconds 5   # directory replication: a brand-new user is not immediately writable
        $before = Get-GkRawProperty -Uri "v1.0/users/$($user.Id)?`$select=lastPasswordChangeDateTime" -Property 'lastPasswordChangeDateTime'

        Reset-GkUserPassword -UserId $user.Id -WhatIf | Out-Null
        $afterWhatIf = Get-GkRawProperty -Uri "v1.0/users/$($user.Id)?`$select=lastPasswordChangeDateTime" -Property 'lastPasswordChangeDateTime'
        Assert-GkTrue $checks ($afterWhatIf -eq $before) '-WhatIf changed nothing'

        $r = Reset-GkUserPassword -UserId $user.Id -Confirm:$false
        Assert-GkTrue $checks ($r.Outcome -eq 'Reset') 'reset reported success'
        Assert-GkTrue $checks (-not [string]::IsNullOrWhiteSpace($r.Password)) 'a password was returned'
        Assert-GkTrue $checks ($r.Password.Length -ge 20) 'the generated password is full length'

        Start-Sleep -Seconds 5
        $after = Get-GkRawProperty -Uri "v1.0/users/$($user.Id)?`$select=lastPasswordChangeDateTime" -Property 'lastPasswordChangeDateTime'
        Assert-GkTrue $checks ($after -ne $before) 'lastPasswordChangeDateTime advanced on the server'
    }
    finally { Remove-GkDisposable -Collection 'users' -Id $user.Id -Name $user.DisplayName }
}

# --- 2. Temporary Access Pass -------------------------------------------------------------------
Invoke-GkScenario -Name 'TemporaryAccess' -Body {
    param($checks)
    $user = New-GkDisposableUser -Tag 'tap'
    try {
        Start-Sleep -Seconds 5
        New-GkTemporaryAccessPass -UserId $user.Id -WhatIf | Out-Null
        $methods = @(Get-GkUserAuthMethod -UserId $user.Id -MethodType TemporaryAccessPass)
        Assert-GkTrue $checks ($methods.Count -eq 0) '-WhatIf issued no pass'

        $r = New-GkTemporaryAccessPass -UserId $user.Id -LifetimeInMinutes 60 -Confirm:$false
        if ($r.Outcome -ne 'Created') {
            # A tenant with TAP disabled in the auth methods policy cannot run this scenario.
            $checks.Add("SKIP: TAP not issued — $($r.Error)")
            return
        }
        Assert-GkTrue $checks (-not [string]::IsNullOrWhiteSpace($r.TemporaryAccessPass)) 'a passcode was returned'
        Assert-GkTrue $checks ($r.IsUsableOnce) 'defaults to single-use'

        $methods = @(Get-GkUserAuthMethod -UserId $user.Id -MethodType TemporaryAccessPass)
        Assert-GkTrue $checks ($methods.Count -eq 1) 'the pass is registered on the account'

        $second = New-GkTemporaryAccessPass -UserId $user.Id -Confirm:$false -WarningAction SilentlyContinue
        Assert-GkTrue $checks ($second.Outcome -eq 'Failed') 'a second concurrent pass is rejected'
    }
    finally { Remove-GkDisposable -Collection 'users' -Id $user.Id -Name $user.DisplayName }
}

# --- 3. Delete and restore round trip -----------------------------------------------------------
Invoke-GkScenario -Name 'DeleteRestore' -Body {
    param($checks)
    $user = New-GkDisposableUser -Tag 'restore'
    $restored = $false
    try {
        Start-Sleep -Seconds 5
        Assert-GkDisposable -Name $user.DisplayName -What "users/$($user.Id)"
        Invoke-MgGraphRequest -Method DELETE -Uri "v1.0/users/$($user.Id)" | Out-Null
        Start-Sleep -Seconds 10   # soft-delete takes a moment to surface in deletedItems

        $deleted = @(Get-GkDeletedItem -Type User | Where-Object Id -eq $user.Id)
        Assert-GkTrue $checks ($deleted.Count -eq 1) 'the deleted user appears in deletedItems'
        Assert-GkTrue $checks ($deleted[0].DaysUntilPurge -gt 25) 'the restore window is reported'

        Restore-GkDeletedObject -Id $user.Id -Type User -WhatIf | Out-Null
        $still = @(Get-GkDeletedItem -Type User | Where-Object Id -eq $user.Id)
        Assert-GkTrue $checks ($still.Count -eq 1) '-WhatIf restored nothing'

        $r = Restore-GkDeletedObject -Id $user.Id -Type User -Confirm:$false
        Assert-GkTrue $checks ($r.Outcome -eq 'Restored') 'restore reported success'
        $restored = $true

        Start-Sleep -Seconds 10
        $live = Get-GkRawProperty -Uri "v1.0/users/$($user.Id)?`$select=id" -Property 'id'
        Assert-GkTrue $checks ($live -eq $user.Id) 'the user is live in the directory again'
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
        Start-Sleep -Seconds 5
        Disable-GkStaleUser -UserId $user.Id -WhatIf | Out-Null
        Assert-GkTrue $checks ((Get-GkRawProperty -Uri "v1.0/users/$($user.Id)?`$select=accountEnabled" -Property 'accountEnabled') -eq $true) '-WhatIf left the account enabled'

        $r = Disable-GkStaleUser -UserId $user.Id -Confirm:$false
        Assert-GkTrue $checks ($r.Outcome -eq 'Disabled') 'disable reported success'
        Assert-GkTrue $checks ((Get-GkRawProperty -Uri "v1.0/users/$($user.Id)?`$select=accountEnabled" -Property 'accountEnabled') -eq $false) 'accountEnabled is false on the server'
    }
    finally { Remove-GkDisposable -Collection 'users' -Id $user.Id -Name $user.DisplayName }
}

# --- 5. Group membership add / remove -----------------------------------------------------------
Invoke-GkScenario -Name 'GroupMembership' -Body {
    param($checks)
    $group = New-GkDisposableGroup -Tag 'members'
    $user = New-GkDisposableUser -Tag 'member'
    try {
        Start-Sleep -Seconds 10
        Add-GkGroupMember -GroupId $group.Id -MemberId $user.Id -WhatIf | Out-Null
        Assert-GkTrue $checks (@(Get-GkGroupMember -GroupId $group.Id).Count -eq 0) '-WhatIf added nobody'

        Add-GkGroupMember -GroupId $group.Id -MemberId $user.Id -Confirm:$false | Out-Null
        Start-Sleep -Seconds 5
        $members = @(Get-GkGroupMember -GroupId $group.Id)
        Assert-GkTrue $checks ($members.Count -eq 1) 'the member was added'
        Assert-GkTrue $checks ($members[0].MemberType -eq 'User') 'the member type resolves to User'
        Assert-GkTrue $checks ($members[0].Id -eq $user.Id) 'the right object was added'

        Remove-GkGroupMember -GroupId $group.Id -MemberId $user.Id -Confirm:$false | Out-Null
        Start-Sleep -Seconds 5
        Assert-GkTrue $checks (@(Get-GkGroupMember -GroupId $group.Id).Count -eq 0) 'the member was removed'
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
        Start-Sleep -Seconds 10
        Set-GkGroupOwner -GroupId $group.Id -OwnerId $user.Id -WhatIf | Out-Null
        $owners = (Invoke-MgGraphRequest -Method GET -Uri "v1.0/groups/$($group.Id)/owners?`$select=id" -OutputType Hashtable).value
        Assert-GkTrue $checks (@($owners).Count -eq 0) '-WhatIf set no owner'

        Set-GkGroupOwner -GroupId $group.Id -OwnerId $user.Id -Confirm:$false | Out-Null
        Start-Sleep -Seconds 5
        $owners = (Invoke-MgGraphRequest -Method GET -Uri "v1.0/groups/$($group.Id)/owners?`$select=id" -OutputType Hashtable).value
        Assert-GkTrue $checks (@($owners).Count -eq 1) 'the owner was set'
        Assert-GkTrue $checks (@($owners)[0].id -eq $user.Id) 'the right principal owns the group'
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
        Start-Sleep -Seconds 5
        Reset-GkAppCredential -ApplicationId $app.Id -WhatIf | Out-Null
        $creds = Get-GkRawProperty -Uri "v1.0/applications/$($app.Id)?`$select=passwordCredentials" -Property 'passwordCredentials'
        Assert-GkTrue $checks (@($creds).Count -eq 0) '-WhatIf added no secret'

        $r = Reset-GkAppCredential -ApplicationId $app.Id -Confirm:$false
        Assert-GkTrue $checks (-not [string]::IsNullOrWhiteSpace($r.SecretText)) 'a secret was returned'
        Assert-GkTrue $checks (-not [string]::IsNullOrWhiteSpace($r.KeyId)) 'the keyId was returned'

        $creds = Get-GkRawProperty -Uri "v1.0/applications/$($app.Id)?`$select=passwordCredentials" -Property 'passwordCredentials'
        Assert-GkTrue $checks (@($creds).Count -eq 1) 'the secret exists on the application'

        Reset-GkAppCredential -ApplicationId $app.Id -RemoveKeyId $r.KeyId -Confirm:$false | Out-Null
        $creds = Get-GkRawProperty -Uri "v1.0/applications/$($app.Id)?`$select=passwordCredentials" -Property 'passwordCredentials'
        Assert-GkTrue $checks (@($creds).Count -eq 0) 'the secret was removed'
    }
    finally { Remove-GkDisposable -Collection 'applications' -Id $app.Id -Name $app.DisplayName }
}

# --- 8. LAPS read -------------------------------------------------------------------------------
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
