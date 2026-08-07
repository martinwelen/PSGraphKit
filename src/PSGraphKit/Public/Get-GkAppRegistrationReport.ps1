function Get-GkAppRegistrationReport {
    <#
    .SYNOPSIS
        Report app registrations with credential (secret/certificate) expiry and high-privilege
        API permissions.

    .DESCRIPTION
        Reads GET /applications and, per app, summarizes:
          * Credentials — passwordCredentials (secrets) and keyCredentials (certificates): counts,
            the earliest upcoming expiry, and how many are expired or expiring within a threshold.
          * Permissions — requiredResourceAccess resolved to human names by looking up each resource
            service principal's appRoles (application permissions, type Role) and oauth2PermissionScopes
            (delegated, type Scope). Application permissions matching a high-risk set (broad *.ReadWrite.All,
            RoleManagement.ReadWrite.Directory, Application.ReadWrite.All, full_access_as_app, ...) are
            flagged. Permission GUIDs are resolved live — never guessed — and cached per run.

        Use -SkipPermissionResolution to skip the service-principal lookups (faster; permissions are
        left as GUIDs and high-privilege detection is unavailable).

    .PARAMETER ExpiringInDays
        Window in days for the ExpiringSoonCount / -ExpiringOnly filter (default 30).

    .PARAMETER ExpiringOnly
        Return only apps with a credential already expired or expiring within ExpiringInDays.

    .PARAMETER HighPrivilegeOnly
        Return only apps holding at least one flagged high-privilege application permission.

    .PARAMETER SkipPermissionResolution
        Do not resolve permission GUIDs to names (skips per-resource servicePrincipal lookups).

    .PARAMETER AsReport
        Flatten HighPrivilegePermissions to a '; '-joined string and add ReportGeneratedUtc.

    .EXAMPLE
        Get-GkAppRegistrationReport -ExpiringInDays 30 -ExpiringOnly | Sort-Object DaysUntilExpiry

        Apps with a secret/cert expired or expiring within 30 days, soonest first.

    .EXAMPLE
        Get-GkAppRegistrationReport -HighPrivilegeOnly |
            Select-Object DisplayName, HighPrivilegePermissions

        Apps granted high-privilege application permissions.

    .EXAMPLE
        Get-GkAppRegistrationReport -SkipPermissionResolution -AsReport |
            Export-Csv .\apps.csv -NoTypeInformation

    .OUTPUTS
        PSGraphKit.AppRegistration
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.AppRegistration')]
    param(
        [ValidateRange(1, 3650)]
        [int] $ExpiringInDays = 30,

        [switch] $ExpiringOnly,

        [switch] $HighPrivilegeOnly,

        [switch] $SkipPermissionResolution,

        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkAppRegistrationReport' -Caller $PSCmdlet | Out-Null
        $now = [datetime]::UtcNow

        $highRiskExact = @(
            'RoleManagement.ReadWrite.Directory', 'Directory.ReadWrite.All', 'Application.ReadWrite.All',
            'AppRoleAssignment.ReadWrite.All', 'Domain.ReadWrite.All', 'PrivilegedAccess.ReadWrite.AzureAD',
            'full_access_as_app'
        )
    }

    process {
        $select = 'id,appId,displayName,signInAudience,passwordCredentials,keyCredentials,requiredResourceAccess'
        $apps = Invoke-GkGraphRequest -Uri "/applications?`$select=$select&`$top=999" -CallerFunction 'Get-GkAppRegistrationReport'

        $spCache = @{}   # resourceAppId -> @{ Role = @{id=name}; Scope = @{id=name} }

        foreach ($app in $apps) {
            # --- Credentials ---
            $creds = @()
            foreach ($pc in @(Get-GkDictValue $app 'passwordCredentials')) {
                $creds += [pscustomobject]@{ Type = 'Secret'; End = (ConvertTo-GkDateTime (Get-GkDictValue $pc 'endDateTime')) }
            }
            foreach ($kc in @(Get-GkDictValue $app 'keyCredentials')) {
                $creds += [pscustomobject]@{ Type = 'Certificate'; End = (ConvertTo-GkDateTime (Get-GkDictValue $kc 'endDateTime')) }
            }
            $secretCount = @($creds | Where-Object Type -eq 'Secret').Count
            $certCount   = @($creds | Where-Object Type -eq 'Certificate').Count

            $withDates    = @($creds | Where-Object { $null -ne $_.End })
            $earliest     = $withDates | Sort-Object End | Select-Object -First 1
            $earliestEnd  = if ($earliest) { $earliest.End } else { $null }
            $daysToExpiry = if ($earliestEnd) { [int][math]::Floor(($earliestEnd - $now).TotalDays) } else { $null }
            $expiredCount = @($withDates | Where-Object { $_.End -lt $now }).Count
            $expiringSoon = @($withDates | Where-Object { $_.End -ge $now -and ($_.End - $now).TotalDays -le $ExpiringInDays }).Count

            # --- Permissions ---
            $appPerms = @(); $delegatedPerms = @(); $highPriv = @()
            if (-not $SkipPermissionResolution) {
                foreach ($rra in @(Get-GkDictValue $app 'requiredResourceAccess')) {
                    $resourceAppId = [string](Get-GkDictValue $rra 'resourceAppId')
                    if (-not $resourceAppId) { continue }

                    if (-not $spCache.ContainsKey($resourceAppId)) {
                        $map = @{ Role = @{}; Scope = @{} }
                        try {
                            $sp = Invoke-GkGraphRequest -Raw -CallerFunction 'Get-GkAppRegistrationReport' `
                                -Uri "/servicePrincipals(appId='$resourceAppId')?`$select=appId,displayName,appRoles,oauth2PermissionScopes"
                            foreach ($ar in @(Get-GkDictValue $sp 'appRoles')) {
                                $map.Role[[string](Get-GkDictValue $ar 'id')] = [string](Get-GkDictValue $ar 'value')
                            }
                            foreach ($os in @(Get-GkDictValue $sp 'oauth2PermissionScopes')) {
                                $map.Scope[[string](Get-GkDictValue $os 'id')] = [string](Get-GkDictValue $os 'value')
                            }
                        }
                        catch {
                            Write-Verbose "PSGraphKit: could not resolve permissions for resource $resourceAppId : $($_.Exception.Message)"
                        }
                        $spCache[$resourceAppId] = $map
                    }
                    $map = $spCache[$resourceAppId]

                    foreach ($ra in @(Get-GkDictValue $rra 'resourceAccess')) {
                        $raId   = [string](Get-GkDictValue $ra 'id')
                        $raType = [string](Get-GkDictValue $ra 'type')   # 'Role' = application, 'Scope' = delegated
                        if ($raType -eq 'Role') {
                            $name = if ($map.Role.ContainsKey($raId)) { $map.Role[$raId] } else { $raId }
                            $appPerms += $name
                            if ($highRiskExact -contains $name -or $name -like '*.ReadWrite.All') { $highPriv += $name }
                        }
                        else {
                            $name = if ($map.Scope.ContainsKey($raId)) { $map.Scope[$raId] } else { $raId }
                            $delegatedPerms += $name
                        }
                    }
                }
            }
            $highPriv = @($highPriv | Sort-Object -Unique)

            $isExpiringCandidate = ($expiredCount -gt 0 -or $expiringSoon -gt 0)
            if ($ExpiringOnly -and -not $isExpiringCandidate) { continue }
            if ($HighPrivilegeOnly -and $highPriv.Count -eq 0) { continue }

            $obj = [ordered]@{
                PSTypeName               = 'PSGraphKit.AppRegistration'
                DisplayName              = [string](Get-GkDictValue $app 'displayName')
                AppId                    = [string](Get-GkDictValue $app 'appId')
                SignInAudience           = [string](Get-GkDictValue $app 'signInAudience')
                SecretCount              = $secretCount
                CertificateCount         = $certCount
                EarliestCredentialExpiry = $earliestEnd
                DaysUntilExpiry          = $daysToExpiry
                ExpiredCredentialCount   = $expiredCount
                ExpiringSoonCount        = $expiringSoon
                AppPermissionCount       = $appPerms.Count
                DelegatedPermissionCount = $delegatedPerms.Count
                HighPrivilegePermissions = if ($AsReport) { $highPriv -join '; ' } else { , $highPriv }
                HasHighPrivilege         = ($highPriv.Count -gt 0)
                Id                       = [string](Get-GkDictValue $app 'id')
            }
            if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
            [pscustomobject]$obj
        }
    }
}
