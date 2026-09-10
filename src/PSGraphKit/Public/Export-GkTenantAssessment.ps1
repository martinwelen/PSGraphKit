function Export-GkTenantAssessment {
    <#
    .SYNOPSIS
        Run the PSGraphKit read suite and export a single self-contained HTML assessment (and
        optionally CSVs) — an engagement deliverable.

    .DESCRIPTION
        Runs a curated set of read-only reports and renders them into one self-contained HTML file
        (inline CSS, no external assets), suitable to hand to a customer. Each report is invoked with
        -AsReport so nested/array values are already flattened for tabular output. A report that
        fails (e.g. a missing scope or license) is skipped with a warning and noted in the document,
        so one gap does not abort the whole assessment.

        Uses only Microsoft.PowerShell.Utility (ConvertTo-Html / Export-Csv) — no reporting-module
        dependency. Read-only; it changes nothing in the tenant. Each underlying report validates its
        own scopes, so connect with a broad read set first (e.g. Connect-GkGraph -AllCommands).

    .PARAMETER Path
        Output HTML file path. Defaults to .\PSGraphKit-Assessment.html.

    .PARAMETER CsvFolder
        If set, also writes one CSV per section into this folder.

    .PARAMETER Include
        Section keys to include (default all). Keys: StaleUsers, Guests, Licenses, Roles, Mfa, Apps,
        Groups, ConditionalAccess, Devices, ServicePrincipals, AuthMethods, NamedLocations,
        CustomRoles, LicenseErrors.

    .PARAMETER PassThru
        Return the generated file object.

    .EXAMPLE
        Connect-GkGraph -AllCommands
        Export-GkTenantAssessment -Path .\contoso.html

        Full assessment to one HTML file.

    .EXAMPLE
        Export-GkTenantAssessment -Include StaleUsers, Guests, Licenses, Roles -CsvFolder .\out

        A focused assessment plus per-section CSVs.

    .EXAMPLE
        Export-GkTenantAssessment -Path .\a.html -PassThru | Invoke-Item

        Generate and open the report.

    .OUTPUTS
        System.IO.FileInfo (with -PassThru)
    #>
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param(
        [string] $Path = (Join-Path (Get-Location) 'PSGraphKit-Assessment.html'),
        [string] $CsvFolder,
        [string[]] $Include,
        [switch] $PassThru
    )

    begin {
        $ctx = Test-GkConnection -FunctionName 'Export-GkTenantAssessment' -Caller $PSCmdlet
        $now = [datetime]::UtcNow
        Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue
    }

    process {
        $sections = [ordered]@{
            StaleUsers        = @{ Title = 'Stale Users';                 Script = { Get-GkStaleUser -AsReport } }
            Guests            = @{ Title = 'Guest Inventory';             Script = { Get-GkGuestInventory -SkipSponsor -AsReport } }
            Licenses          = @{ Title = 'License Overview';            Script = { Get-GkLicenseOverview -AsReport } }
            Roles             = @{ Title = 'Admin Role Assignments';      Script = { Get-GkAdminRoleAssignment -AsReport } }
            Mfa               = @{ Title = 'MFA Registration';           Script = { Get-GkUserMfaStatus -AsReport } }
            Apps              = @{ Title = 'App Registrations';           Script = { Get-GkAppRegistrationReport -AsReport } }
            Groups            = @{ Title = 'Groups';                      Script = { Get-GkGroupReport -SkipMemberCount -AsReport } }
            ConditionalAccess = @{ Title = 'Conditional Access Policies'; Script = { Get-GkCaPolicyReport -AsReport } }
            Devices           = @{ Title = 'Devices';                     Script = { Get-GkDeviceInventory -AsReport } }
            ServicePrincipals = @{ Title = 'Service Principals';          Script = { Get-GkServicePrincipalReport -AsReport } }
            AuthMethods       = @{ Title = 'Authentication Methods';      Script = { Get-GkAuthMethodPolicy -AsReport } }
            NamedLocations    = @{ Title = 'Named Locations';             Script = { Get-GkNamedLocation -AsReport } }
            CustomRoles       = @{ Title = 'Custom Roles';                Script = { Get-GkCustomRole -AsReport } }
            LicenseErrors     = @{ Title = 'License Assignment Errors';   Script = { Get-GkLicenseAssignmentError -AsReport } }
        }

        $keys = if ($Include) { $Include } else { @($sections.Keys) }
        if ($CsvFolder -and -not (Test-Path $CsvFolder)) { New-Item -ItemType Directory -Path $CsvFolder -Force | Out-Null }

        $fragments = [System.Collections.Generic.List[string]]::new()
        $tenant = if ($ctx) { $ctx.TenantId } else { 'unknown' }
        $account = if ($ctx) { $ctx.Account } else { 'unknown' }
        $fragments.Add("<h1>Microsoft Entra Tenant Assessment</h1>")
        $fragments.Add("<p class='meta'>Tenant $tenant &middot; generated $($now.ToString('u')) by $account</p>")

        foreach ($key in $keys) {
            if (-not $sections.Contains($key)) { Write-Warning "Unknown section '$key' — skipped."; continue }
            $section = $sections[$key]
            Write-Verbose "Assessment section: $($section.Title)"
            try {
                $data = @(& $section.Script -WarningAction SilentlyContinue -ErrorAction Stop)
                if ($data.Count -eq 0) {
                    $fragments.Add("<h2>$($section.Title)</h2><p class='empty'>No data.</p>")
                }
                else {
                    $fragments.Add(($data | ConvertTo-Html -Fragment -PreContent "<h2>$($section.Title) <span class='count'>($($data.Count))</span></h2>" | Out-String))
                    if ($CsvFolder) { $data | Export-Csv -Path (Join-Path $CsvFolder "$key.csv") -NoTypeInformation -Encoding UTF8 }
                }
            }
            catch {
                Write-Warning "Section '$($section.Title)' failed and was skipped: $($_.Exception.Message)"
                $fragments.Add("<h2>$($section.Title)</h2><p class='error'>Unavailable: $([System.Web.HttpUtility]::HtmlEncode($_.Exception.Message))</p>")
            }
        }

        $head = @'
<style>
body { font-family: Segoe UI, Arial, sans-serif; margin: 2rem; color: #222; }
h1 { border-bottom: 3px solid #0067b8; padding-bottom: .3rem; }
h2 { color: #0067b8; margin-top: 2rem; border-bottom: 1px solid #ddd; padding-bottom: .2rem; }
.meta { color: #666; }
.count { color: #888; font-weight: normal; font-size: .8em; }
.empty { color: #888; font-style: italic; }
.error { color: #a80000; }
table { border-collapse: collapse; width: 100%; margin: .5rem 0; font-size: .85rem; }
th { background: #0067b8; color: #fff; text-align: left; padding: 6px 8px; }
td { border: 1px solid #ddd; padding: 4px 8px; vertical-align: top; }
tr:nth-child(even) td { background: #f6f8fa; }
</style>
<title>Entra Tenant Assessment</title>
'@

        ConvertTo-Html -Head $head -Body ($fragments -join "`n") | Out-File -FilePath $Path -Encoding utf8
        Write-Verbose "Wrote assessment to $Path"

        if ($PassThru) { Get-Item -Path $Path }
    }
}
