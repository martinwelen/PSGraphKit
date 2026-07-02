@{
    # PSGraphKit targets PowerShell 7.4+ only (Windows PowerShell 5.1 is NOT a target).
    Severity = @('Error', 'Warning')

    IncludeDefaultRules = $true

    ExcludeRules = @(
        # Phase 1 is read-only, so SupportsShouldProcess is not applicable.
        'PSUseShouldProcessForStateChangingFunctions',

        # We target PowerShell 7.4+ only, where UTF-8 *without* BOM is the default and correct
        # encoding. The BOM rule exists for Windows PowerShell 5.1 (not a target), so a BOM would
        # be actively wrong here. Source files are UTF-8 and may contain non-ASCII text in comments.
        'PSUseBOMForUnicodeEncodedFile'
    )

    Rules = @{
        PSUseCompatibleSyntax = @{
            Enable         = $true
            TargetVersions = @('7.4')
        }
    }
}
