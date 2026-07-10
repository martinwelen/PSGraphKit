function Get-GkDeviceInventory {
    <#
    .SYNOPSIS
        Inventory Entra-registered/joined devices with OS, join type, last activity, and a stale flag.

    .DESCRIPTION
        Reads GET /devices and reports each device's operating system, join type, compliance/management
        state, and inactivity derived from approximateLastSignInDateTime. Devices with no recorded
        activity are treated as stale.

        Join type is mapped from trustType (per Microsoft Graph):
          * AzureAd   -> AzureADJoined   (cloud-only Entra joined)
          * ServerAd  -> HybridJoined    (on-premises AD domain / hybrid joined)  [there is no "Hybrid" literal]
          * Workplace -> Registered      (personal / BYO registered)

        Note: approximateLastSignInDateTime is APPROXIMATE — Entra updates it periodically, not in
        real time — so treat the stale threshold as indicative, not exact.

    .PARAMETER StaleDays
        Inactivity threshold in days (default 90). A device is stale when its last activity is at
        least this many days ago, or when it has no recorded activity.

    .PARAMETER StaleOnly
        Return only stale devices.

    .PARAMETER JoinType
        Filter by join type: All (default), AzureADJoined, HybridJoined, or Registered.

    .PARAMETER AsReport
        Add a ReportGeneratedUtc column for clean export.

    .EXAMPLE
        Get-GkDeviceInventory -StaleOnly -StaleDays 180 | Sort-Object InactiveDays -Descending

        Devices with no activity for 180+ days, most inactive first.

    .EXAMPLE
        Get-GkDeviceInventory -JoinType Registered | Where-Object { -not $_.IsCompliant }

        Personal (registered) devices that are not compliant.

    .EXAMPLE
        Get-GkDeviceInventory -AsReport | Export-Csv .\devices.csv -NoTypeInformation

    .OUTPUTS
        PSGraphKit.Device
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.Device')]
    param(
        [ValidateRange(1, 3650)]
        [int] $StaleDays = 90,

        [switch] $StaleOnly,

        [ValidateSet('All', 'AzureADJoined', 'HybridJoined', 'Registered')]
        [string] $JoinType = 'All',

        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkDeviceInventory' | Out-Null
        $now = [datetime]::UtcNow
    }

    process {
        $select = 'id,deviceId,displayName,operatingSystem,operatingSystemVersion,trustType,approximateLastSignInDateTime,registrationDateTime,accountEnabled,isCompliant,isManaged,deviceOwnership'
        $devices = Invoke-GkGraphRequest -Uri "/devices?`$select=$select&`$top=999" -CallerFunction 'Get-GkDeviceInventory'

        foreach ($d in $devices) {
            $trustType = [string](Get-GkDictValue $d 'trustType')
            $deviceJoin = switch ($trustType) {
                'AzureAd'   { 'AzureADJoined' }
                'ServerAd'  { 'HybridJoined' }
                'Workplace' { 'Registered' }
                default     { if ($trustType) { $trustType } else { 'Unknown' } }
            }
            if ($JoinType -ne 'All' -and $deviceJoin -ne $JoinType) { continue }

            $lastActivity  = ConvertTo-GkDateTime (Get-GkDictValue $d 'approximateLastSignInDateTime')
            $registered    = ConvertTo-GkDateTime (Get-GkDictValue $d 'registrationDateTime')
            $neverActive   = ($null -eq $lastActivity)
            $inactiveDays  = if ($neverActive) { $null } else { [int][math]::Floor(($now - $lastActivity).TotalDays) }
            # A device with no sign-in activity is stale only if it also was not registered within
            # StaleDays — otherwise a freshly-registered device whose (approximate, periodically-updated)
            # sign-in hasn't populated yet is a false positive in the very stale list this cmdlet produces.
            $isStale = if ($neverActive) {
                ($null -eq $registered) -or ((($now - $registered).TotalDays) -ge $StaleDays)
            }
            else { $inactiveDays -ge $StaleDays }

            if ($StaleOnly -and -not $isStale) { continue }

            # Preserve tri-state: an absent isCompliant/isManaged means "not evaluated", not $false.
            $compliantRaw = Get-GkDictValue $d 'isCompliant'
            $managedRaw   = Get-GkDictValue $d 'isManaged'

            $obj = [ordered]@{
                PSTypeName      = 'PSGraphKit.Device'
                DisplayName     = [string](Get-GkDictValue $d 'displayName')
                OperatingSystem = [string](Get-GkDictValue $d 'operatingSystem')
                OSVersion       = [string](Get-GkDictValue $d 'operatingSystemVersion')
                JoinType        = $deviceJoin
                TrustType       = $trustType
                LastActivity    = $lastActivity
                InactiveDays    = $inactiveDays
                NeverActive     = $neverActive
                IsStale         = $isStale
                IsCompliant     = if ($null -eq $compliantRaw) { $null } else { [bool]$compliantRaw }
                IsManaged       = if ($null -eq $managedRaw) { $null } else { [bool]$managedRaw }
                AccountEnabled  = [bool](Get-GkDictValue $d 'accountEnabled')
                Ownership       = [string](Get-GkDictValue $d 'deviceOwnership')
                Registered      = $registered
                DeviceId        = [string](Get-GkDictValue $d 'deviceId')
                Id              = [string](Get-GkDictValue $d 'id')
            }
            if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
            [pscustomobject]$obj
        }
    }
}
