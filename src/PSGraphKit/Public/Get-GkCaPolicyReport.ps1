function Get-GkCaPolicyReport {
    <#
    .SYNOPSIS
        Report Conditional Access policies with their state and human-readable summaries of the
        targeted users/apps and the grant/session controls.

    .DESCRIPTION
        Reads GET /identity/conditionalAccess/policies and flattens each policy's nested
        conditions and controls into readable columns: who it targets (included/excluded users,
        groups, roles), which apps, the client app types, the grant controls (e.g. "mfa AND
        compliantDevice", or "Block"), and which session controls are enabled. The raw builtInControls
        and enabled session-control names are kept as arrays for scripting.

        Requires the Policy.Read.All scope.

    .PARAMETER State
        Filter by state: All (default), Enabled, Disabled, or ReportOnly
        (enabledForReportingButNotEnforced).

    .PARAMETER AsReport
        Flatten the array columns (BuiltInControls, SessionControls, ClientAppTypes) to '; '-joined
        strings and add ReportGeneratedUtc.

    .EXAMPLE
        Get-GkCaPolicyReport | Format-Table DisplayName, State, GrantControls

        All CA policies with their state and grant controls.

    .EXAMPLE
        Get-GkCaPolicyReport -State Disabled

        Policies that are currently switched off.

    .EXAMPLE
        Get-GkCaPolicyReport -AsReport | Export-Csv .\ca-policies.csv -NoTypeInformation

    .OUTPUTS
        PSGraphKit.CaPolicy
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.CaPolicy')]
    param(
        [ValidateSet('All', 'Enabled', 'Disabled', 'ReportOnly')]
        [string] $State = 'All',

        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkCaPolicyReport' | Out-Null
        $now = [datetime]::UtcNow

        $stateFilter = switch ($State) {
            'Enabled'    { 'enabled' }
            'Disabled'   { 'disabled' }
            'ReportOnly' { 'enabledForReportingButNotEnforced' }
            default      { $null }
        }
    }

    process {
        $policies = Invoke-GkGraphRequest -Uri '/identity/conditionalAccess/policies' -CallerFunction 'Get-GkCaPolicyReport'

        foreach ($p in $policies) {
            $policyState = [string](Get-GkDictValue $p 'state')
            if ($stateFilter -and $policyState -ne $stateFilter) { continue }

            $conditions   = Get-GkDictValue $p 'conditions'
            $usersCond    = Get-GkDictValue $conditions 'users'
            $appsCond     = Get-GkDictValue $conditions 'applications'
            $grantCtrls   = Get-GkDictValue $p 'grantControls'
            $sessionCtrls = Get-GkDictValue $p 'sessionControls'

            # --- Targeted users summary ---
            $incUsers  = @(Get-GkDictValue $usersCond 'includeUsers')
            $incGroups = @(Get-GkDictValue $usersCond 'includeGroups')
            $incRoles  = @(Get-GkDictValue $usersCond 'includeRoles')
            $excUsers  = @(Get-GkDictValue $usersCond 'excludeUsers')
            $excGroups = @(Get-GkDictValue $usersCond 'excludeGroups')
            $excRoles  = @(Get-GkDictValue $usersCond 'excludeRoles')

            $includedUsers =
                if ($incUsers -contains 'All')  { 'All users' }
                elseif ($incUsers -contains 'None') { 'None' }
                else { '{0} user(s), {1} group(s), {2} role(s)' -f $incUsers.Count, $incGroups.Count, $incRoles.Count }
            $excludedUsers = '{0} user(s), {1} group(s), {2} role(s)' -f $excUsers.Count, $excGroups.Count, $excRoles.Count

            # --- Targeted apps summary ---
            $incApps = @(Get-GkDictValue $appsCond 'includeApplications')
            $targetApps =
                if ($incApps -contains 'All')  { 'All cloud apps' }
                elseif ($incApps -contains 'None') { 'None' }
                elseif ($incApps.Count -eq 0)  { '(unspecified)' }
                else { '{0} app(s)' -f $incApps.Count }

            $clientAppTypes = @(Get-GkDictValue $conditions 'clientAppTypes')

            # --- Grant controls summary ---
            $builtIn  = @(Get-GkDictValue $grantCtrls 'builtInControls')
            $operator = [string](Get-GkDictValue $grantCtrls 'operator')
            $authStrength = Get-GkDictValue $grantCtrls 'authenticationStrength'
            $grantSummary =
                if ($null -eq $grantCtrls) { '(none)' }
                elseif ($builtIn -contains 'block') { 'Block' }
                else {
                    $parts = @($builtIn)
                    if ($null -ne $authStrength) { $parts += 'authenticationStrength' }
                    if ($parts.Count -gt 0) { $parts -join " $operator " } else { '(none)' }
                }

            # --- Session controls (names of the enabled/present ones) ---
            $sessionNames = @()
            if ($sessionCtrls -is [System.Collections.IDictionary]) {
                foreach ($key in $sessionCtrls.Keys) {
                    if ([string]$key -like '@*') { continue }   # skip @odata.* metadata keys
                    $val = $sessionCtrls[$key]
                    if ($null -eq $val) { continue }
                    # Scalar-boolean session settings (e.g. disableResilienceDefaults, secureSignInSession)
                    # are only "on" when true — a plain $false must not be listed as enabled.
                    if ($val -is [bool]) { if ($val) { $sessionNames += [string]$key }; continue }
                    if ($val -is [System.Collections.IDictionary] -and $val.Contains('isEnabled') -and -not [bool]$val['isEnabled']) { continue }
                    $sessionNames += [string]$key
                }
            }

            $obj = [ordered]@{
                PSTypeName       = 'PSGraphKit.CaPolicy'
                DisplayName      = [string](Get-GkDictValue $p 'displayName')
                State            = $policyState
                IncludedUsers    = $includedUsers
                ExcludedUsers    = $excludedUsers
                TargetApps       = $targetApps
                GrantControls    = $grantSummary
                BuiltInControls  = if ($AsReport) { $builtIn -join '; ' } else { , $builtIn }
                SessionControls  = if ($AsReport) { $sessionNames -join '; ' } else { , $sessionNames }
                ClientAppTypes   = if ($AsReport) { $clientAppTypes -join '; ' } else { , $clientAppTypes }
                CreatedDateTime  = ConvertTo-GkDateTime (Get-GkDictValue $p 'createdDateTime')
                ModifiedDateTime = ConvertTo-GkDateTime (Get-GkDictValue $p 'modifiedDateTime')
                Id               = [string](Get-GkDictValue $p 'id')
            }
            if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
            [pscustomobject]$obj
        }
    }
}
