function Get-GkServiceHealth {
    <#
    .SYNOPSIS
        Report the current health of each Microsoft 365 service, with active incidents.

    .DESCRIPTION
        Reads GET /admin/serviceAnnouncement/healthOverviews for the per-service status, and with
        -IncludeIssue also pulls the open issues behind any service that is not healthy. This is the
        "is it us or is it Microsoft" check — worth running before you start debugging a tenant.

        Requires the ServiceHealth.Read.All scope, which is the only permission Graph accepts for
        this API.

    .PARAMETER Service
        Only return services whose name contains this text (case-insensitive), e.g. 'Exchange'.

    .PARAMETER UnhealthyOnly
        Only return services that are not reporting serviceOperational.

    .PARAMETER IncludeIssue
        Add the open issues for each returned service. Costs one extra Graph call.

    .PARAMETER AsReport
        Add a ReportGeneratedUtc column.

    .EXAMPLE
        Get-GkServiceHealth -UnhealthyOnly

        Only the services currently degraded or in incident.

    .EXAMPLE
        Get-GkServiceHealth -UnhealthyOnly -IncludeIssue

        Degraded services with the incidents behind them.

    .EXAMPLE
        Get-GkServiceHealth -AsReport | Export-Csv .\service-health.csv -NoTypeInformation

    .OUTPUTS
        PSGraphKit.ServiceHealth
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.ServiceHealth')]
    param(
        [string] $Service,

        [switch] $UnhealthyOnly,

        [switch] $IncludeIssue,

        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkServiceHealth' -Caller $PSCmdlet | Out-Null
        $now = [datetime]::UtcNow
    }

    process {
        $overviews = Invoke-GkGraphRequest -Uri '/admin/serviceAnnouncement/healthOverviews' -CallerFunction 'Get-GkServiceHealth'

        # Pull issues once and group them, rather than per service.
        $issuesByService = @{}
        if ($IncludeIssue) {
            try {
                $issues = Invoke-GkGraphRequest -Uri '/admin/serviceAnnouncement/issues' -CallerFunction 'Get-GkServiceHealth'
                foreach ($i in $issues) {
                    if ([string](Get-GkDictValue $i 'isResolved') -eq 'True') { continue }
                    $svc = [string](Get-GkDictValue $i 'service')
                    if (-not $issuesByService.ContainsKey($svc)) { $issuesByService[$svc] = @() }
                    $issuesByService[$svc] += "$([string](Get-GkDictValue $i 'id')): $([string](Get-GkDictValue $i 'title'))"
                }
            }
            catch {
                Write-Warning "Could not read service issues; reporting status only. $($_.Exception.Message)"
            }
        }

        foreach ($o in $overviews) {
            $name = [string](Get-GkDictValue $o 'service')
            $status = [string](Get-GkDictValue $o 'status')

            if ($Service -and $name -notlike "*$Service*") { continue }
            if ($UnhealthyOnly -and $status -eq 'serviceOperational') { continue }

            $obj = [ordered]@{
                PSTypeName = 'PSGraphKit.ServiceHealth'
                Service    = $name
                Status     = $status
                IsHealthy  = ($status -eq 'serviceOperational')
                Id         = [string](Get-GkDictValue $o 'id')
            }
            if ($IncludeIssue) {
                # A missing key yields $null, and @($null) is a one-element array — check the key.
                $open = @()
                if ($issuesByService.ContainsKey($name)) { $open = @($issuesByService[$name]) }
                $obj['OpenIssueCount'] = $open.Count
                if ($AsReport) { $obj['OpenIssues'] = ($open -join '; ') }
                else { $obj['OpenIssues'] = [string[]]$open }
            }
            if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
            [pscustomobject]$obj
        }
    }
}
