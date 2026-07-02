#Requires -Version 7.4
<#
.SYNOPSIS
    Read-only live smoke test for PSGraphKit against a real Microsoft Graph tenant.

.DESCRIPTION
    Exercises every Phase 1 cmdlet end-to-end and prints a per-cmdlet pass/fail summary
    (status, row count, elapsed seconds, first warning/error). Everything here is READ-ONLY —
    no writes, no state changes — so it is safe to run against any tenant you can read.

    Because Microsoft Graph auth is interactive and does not survive across separate processes,
    run this in YOUR own terminal, not through an automated tool. Connect first (or pass -Login):

        Connect-GkGraph -AllCommands           # interactive sign-in with the full read-only scope set
        ./build/Invoke-GkSmokeTest.ps1

    Then paste the printed summary back for interpretation.

.PARAMETER Login
    Connect first via Connect-GkGraph -AllCommands (interactive browser sign-in) before testing.

.PARAMETER UserId
    User (UPN or object id) to use for Get-GkUserAccessReport. Defaults to the signed-in account.

.EXAMPLE
    ./build/Invoke-GkSmokeTest.ps1 -Login

.EXAMPLE
    Connect-GkGraph -AllCommands
    ./build/Invoke-GkSmokeTest.ps1 -UserId ada@contoso.com
#>
[CmdletBinding()]
param(
    [switch] $Login,
    [string] $UserId
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

# Each probe is read-only. Warnings (e.g. no P1/P2, no PIM P2) are expected and reported, not failures.
$probes = [ordered]@{
    'Get-GkConnectionInfo'        = { Get-GkConnectionInfo }
    'Get-GkStaleUser'             = { Get-GkStaleUser -InactiveDays 90 }
    'Get-GkGuestInventory'        = { Get-GkGuestInventory -SkipSponsor }
    'Get-GkLicenseOverview'       = { Get-GkLicenseOverview }
    'Get-GkAdminRoleAssignment'   = { Get-GkAdminRoleAssignment }
    'Get-GkUserMfaStatus'         = { Get-GkUserMfaStatus }
    'Get-GkUserAccessReport'      = { if ($UserId) { Get-GkUserAccessReport -UserId $UserId } else { @() } }
    'Get-GkAppRegistrationReport' = { Get-GkAppRegistrationReport }
    'Get-GkGroupReport'           = { Get-GkGroupReport -SkipMemberCount }
    'Get-GkCaPolicyReport'        = { Get-GkCaPolicyReport }
    'Get-GkDeviceInventory'       = { Get-GkDeviceInventory }
}

$results = foreach ($name in $probes.Keys) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $warns = @()
    try {
        $out = Invoke-Command -ScriptBlock $probes[$name] -WarningVariable warns -WarningAction SilentlyContinue
        $sw.Stop()
        [pscustomobject]@{
            Cmdlet  = $name
            Status  = if ($warns.Count -gt 0) { 'WARN' } else { 'OK' }
            Rows    = @($out).Count
            Seconds = [math]::Round($sw.Elapsed.TotalSeconds, 1)
            Note    = if ($warns.Count -gt 0) { ([string]$warns[0]).Split([char]10)[0] } else { '' }
        }
    }
    catch {
        $sw.Stop()
        [pscustomobject]@{
            Cmdlet  = $name
            Status  = 'FAIL'
            Rows    = 0
            Seconds = [math]::Round($sw.Elapsed.TotalSeconds, 1)
            Note    = $_.Exception.Message.Split([char]10)[0]
        }
    }
}

$results | Format-Table -AutoSize | Out-String | Write-Information -InformationAction Continue

$fail = @($results | Where-Object Status -eq 'FAIL').Count
$warn = @($results | Where-Object Status -eq 'WARN').Count
$ok   = @($results | Where-Object Status -eq 'OK').Count
Write-Information "Smoke test: $ok OK, $warn WARN, $fail FAIL (of $($results.Count))." -InformationAction Continue

# Emit the results object so it can be captured/piped, and set a non-zero-ish signal via output.
$results
