# Export-GkTenantAssessment

## SYNOPSIS
Run the PSGraphKit read suite and export a single self-contained HTML assessment (and
optionally CSVs) — an engagement deliverable.

## SYNTAX
```
Export-GkTenantAssessment [[-Path] <string>] [[-CsvFolder] <string>] [[-Include] <string[]>] [-PassThru] [<CommonParameters>]
```

## DESCRIPTION
Runs a curated set of read-only reports and renders them into one self-contained HTML file
(inline CSS, no external assets), suitable to hand to a customer. Each report is invoked with
-AsReport so nested/array values are already flattened for tabular output. A report that
fails (e.g. a missing scope or license) is skipped with a warning and noted in the document,
so one gap does not abort the whole assessment.

Uses only Microsoft.PowerShell.Utility (ConvertTo-Html / Export-Csv) — no reporting-module
dependency. Read-only; it changes nothing in the tenant. Each underlying report validates its
own scopes, so connect with a broad read set first (e.g. Connect-GkGraph -AllCommands).

## EXAMPLES

### Example 1
```powershell
Connect-GkGraph -AllCommands
Export-GkTenantAssessment -Path .\contoso.html
```
Full assessment to one HTML file.

### Example 2
```powershell
Export-GkTenantAssessment -Include StaleUsers, Guests, Licenses, Roles -CsvFolder .\out
```
A focused assessment plus per-section CSVs.

### Example 3
```powershell
Export-GkTenantAssessment -Path .\a.html -PassThru | Invoke-Item
```
Generate and open the report.

## PARAMETERS

### -Path
Output HTML file path. Defaults to .\PSGraphKit-Assessment.html.

```yaml
Type: String
Required: false
Position: 1
Default value: (Join-Path (Get-Location) 'PSGraphKit-Assessment.html')
Accept pipeline input: false
```

### -CsvFolder
If set, also writes one CSV per section into this folder.

```yaml
Type: String
Required: false
Position: 2
Default value: None
Accept pipeline input: false
```

### -Include
Section keys to include (default all). Keys: StaleUsers, Guests, Licenses, Roles, Mfa, Apps,
Groups, ConditionalAccess, Devices, ServicePrincipals, AuthMethods, NamedLocations,
CustomRoles, LicenseErrors.

```yaml
Type: String[]
Required: false
Position: 3
Default value: None
Accept pipeline input: false
```

### -PassThru
Return the generated file object.

```yaml
Type: SwitchParameter
Required: false
Position: named
Default value: False
Accept pipeline input: false
```

### CommonParameters
This cmdlet supports the common parameters: -Verbose, -Debug, -ErrorAction, -ErrorVariable, -WarningAction, -WarningVariable, -OutVariable, -OutBuffer, and -PipelineVariable. For more information, see about_CommonParameters.

## INPUTS
### None

## OUTPUTS
### System.IO.FileInfo (with -PassThru)
