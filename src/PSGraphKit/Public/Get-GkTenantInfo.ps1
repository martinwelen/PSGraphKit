function Get-GkTenantInfo {
    <#
    .SYNOPSIS
        Report high-level tenant information: name, type, directory size, sync status, contacts.

    .DESCRIPTION
        Reads GET /organization and returns a single object summarizing the tenant — useful as the
        header of an assessment. Requires the Organization.Read.All scope (with only User.Read most
        fields return null).

    .PARAMETER AsReport
        Flatten TechnicalNotificationMails to a '; '-joined string and add ReportGeneratedUtc.

    .EXAMPLE
        Get-GkTenantInfo

        The tenant overview.

    .EXAMPLE
        Get-GkTenantInfo | Select-Object DisplayName, TenantId, OnPremisesSyncEnabled, DirectoryUsersUsed

    .EXAMPLE
        Get-GkTenantInfo -AsReport | Export-Csv .\tenant-info.csv -NoTypeInformation

    .OUTPUTS
        PSGraphKit.TenantInfo
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.TenantInfo')]
    param(
        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkTenantInfo' | Out-Null
        $now = [datetime]::UtcNow
    }

    process {
        # Invoke-GkGraphRequest returns the collection as a single (non-unrolled) object; index an
        # assigned variable rather than @(...) | Select-Object -First 1, which would return the whole
        # array and null every field below.
        $orgs = Invoke-GkGraphRequest -Uri '/organization' -CallerFunction 'Get-GkTenantInfo'
        if (-not $orgs) { Write-Warning 'No organization data was returned.'; return }
        $org = @($orgs)[0]

        $quota = Get-GkDictValue $org 'directorySizeQuota'
        $domains = @(Get-GkDictValue $org 'verifiedDomains')
        $defaultDomain = ($domains | Where-Object { [bool](Get-GkDictValue $_ 'isDefault') } | Select-Object -First 1)
        $mails = @(Get-GkDictValue $org 'technicalNotificationMails')

        $obj = [ordered]@{
            PSTypeName                 = 'PSGraphKit.TenantInfo'
            DisplayName                = [string](Get-GkDictValue $org 'displayName')
            TenantId                   = [string](Get-GkDictValue $org 'id')
            TenantType                 = [string](Get-GkDictValue $org 'tenantType')
            OnPremisesSyncEnabled      = [bool](Get-GkDictValue $org 'onPremisesSyncEnabled')
            CreatedDateTime            = ConvertTo-GkDateTime (Get-GkDictValue $org 'createdDateTime')
            VerifiedDomainCount        = $domains.Count
            DefaultDomain              = if ($defaultDomain) { [string](Get-GkDictValue $defaultDomain 'name') } else { $null }
            DirectoryUsersUsed         = [int](Get-GkDictValue $quota 'used')
            DirectoryQuotaTotal        = [int](Get-GkDictValue $quota 'total')
            TechnicalNotificationMails = if ($AsReport) { $mails -join '; ' } else { $mails }
        }
        if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
        [pscustomobject]$obj
    }
}
