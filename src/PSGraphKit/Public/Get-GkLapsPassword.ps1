function Get-GkLapsPassword {
    <#
    .SYNOPSIS
        Retrieve the Windows LAPS local administrator password for a device.

    .DESCRIPTION
        Reads GET /directory/deviceLocalCredentials/{deviceId}?$select=credentials, which returns
        the Windows LAPS-managed local administrator account and its password, plus any previous
        credentials still within the backup window.

        Without -DeviceId the cmdlet instead lists which devices have LAPS credentials at all —
        useful for confirming coverage. Graph enforces the split, and so do the scopes: the list
        endpoint documents DeviceLocalCredential.ReadBasic.All and deliberately excludes passwords,
        while retrieving one requires DeviceLocalCredential.Read.All. Only the scope for the mode
        you are using is validated.

        The password is returned as plain text on the result but is NOT shown by the default view,
        so it does not splash across the screen or into a transcript. Capture it deliberately with
        Select-Object Password. Reading a LAPS password is an audited, privileged action, and the
        password should be rotated afterwards.

    .PARAMETER DeviceId
        One or more device IDs (the Entra deviceId, not the object id). Accepts pipeline input by
        the DeviceId property, so Get-GkDeviceInventory output can be piped in. Omit to list
        devices that have credentials, without retrieving any password.

    .PARAMETER IncludePrevious
        Also return credentials older than the current one, where the backup window still holds
        them. Off by default: the current password is almost always what you want.

    .PARAMETER AsReport
        Add a ReportGeneratedUtc column.

    .EXAMPLE
        Get-GkLapsPassword -DeviceId $deviceId | Select-Object DeviceName, AccountName, Password

        Retrieve the current local administrator password for one device.

    .EXAMPLE
        Get-GkLapsPassword

        List the devices that have LAPS credentials, without reading any password.

    .EXAMPLE
        Get-GkDeviceInventory -StaleOnly | Get-GkLapsPassword -IncludePrevious

    .OUTPUTS
        PSGraphKit.LapsCredential
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.LapsCredential')]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string[]] $DeviceId,

        [switch] $IncludePrevious,

        [switch] $AsReport
    )

    begin {
        # Listing needs only the ReadBasic scope; retrieving a password needs the full read.
        $scopeVariant = ''
        if ($PSBoundParameters.ContainsKey('DeviceId')) { $scopeVariant = 'Password' }
        Test-GkConnection -FunctionName 'Get-GkLapsPassword' -Variant $scopeVariant -Caller $PSCmdlet | Out-Null
        $now = [datetime]::UtcNow
        $listed = $false
    }

    process {
        if (-not $PSBoundParameters.ContainsKey('DeviceId')) {
            # Inventory mode: one call, and only on the first pipeline pass.
            if ($listed) { return }
            $listed = $true

            $infos = Invoke-GkGraphRequest -Uri '/directory/deviceLocalCredentials' -CallerFunction 'Get-GkLapsPassword'
            foreach ($i in $infos) {
                $obj = [ordered]@{
                    PSTypeName         = 'PSGraphKit.LapsCredential'
                    DeviceName         = [string](Get-GkDictValue $i 'deviceName')
                    DeviceId           = [string](Get-GkDictValue $i 'id')
                    AccountName        = ''      # the list endpoint returns no credential detail
                    LastBackupDateTime = ConvertTo-GkDateTime (Get-GkDictValue $i 'lastBackupDateTime')
                    RefreshDateTime    = ConvertTo-GkDateTime (Get-GkDictValue $i 'refreshDateTime')
                    IsCurrent          = $true
                    Password           = $null   # never returned by the list endpoint, by design
                }
                if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
                [pscustomobject]$obj
            }
            return
        }

        foreach ($did in $DeviceId) {
            if ([string]::IsNullOrWhiteSpace($did)) { continue }
            $enc = [uri]::EscapeDataString($did)

            try {
                $info = Invoke-GkGraphRequest -Raw -Uri "/directory/deviceLocalCredentials/$enc`?`$select=id,deviceName,lastBackupDateTime,refreshDateTime,credentials" `
                    -CallerFunction 'Get-GkLapsPassword'
            }
            catch {
                Write-Warning "Could not read LAPS credentials for device '$did': $($_.Exception.Message)"
                continue
            }

            $deviceName = [string](Get-GkDictValue $info 'deviceName')
            $lastBackup = ConvertTo-GkDateTime (Get-GkDictValue $info 'lastBackupDateTime')
            $refresh = ConvertTo-GkDateTime (Get-GkDictValue $info 'refreshDateTime')

            # credentials is newest-first; older entries exist only while the backup window holds them.
            $creds = @(Get-GkDictValue $info 'credentials')
            $index = 0
            foreach ($c in $creds) {
                $isCurrent = ($index -eq 0)
                $index++
                if (-not $isCurrent -and -not $IncludePrevious) { continue }

                # passwordBase64 is base64-encoded, not encrypted; decode it for the caller.
                $encoded = [string](Get-GkDictValue $c 'passwordBase64')
                $plain = $null
                if ($encoded) {
                    try { $plain = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($encoded)) }
                    catch { $plain = $encoded }
                }

                $obj = [ordered]@{
                    PSTypeName         = 'PSGraphKit.LapsCredential'
                    DeviceName         = $deviceName
                    DeviceId           = $did
                    AccountName        = [string](Get-GkDictValue $c 'accountName')
                    LastBackupDateTime = ConvertTo-GkDateTime (Get-GkDictValue $c 'backupDateTime')
                    RefreshDateTime    = $refresh
                    IsCurrent          = $isCurrent
                    Password           = $plain
                }
                if (-not $obj['LastBackupDateTime']) { $obj['LastBackupDateTime'] = $lastBackup }
                if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
                [pscustomobject]$obj
            }
        }
    }
}
