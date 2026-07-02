function ConvertTo-GkDateTime {
    <#
    .SYNOPSIS
        Convert a Graph ISO-8601 DateTimeOffset string to [datetime] (UTC), or $null.
    .DESCRIPTION
        Graph returns timestamps as ISO-8601 strings (e.g. 2024-05-01T12:00:00Z). Output
        objects expose [datetime], never strings. Missing/empty/unparseable input returns $null
        so callers can safely compute age with null-guards.
    #>
    [CmdletBinding()]
    [OutputType([datetime], [System.Nullable[datetime]])]
    param(
        [Parameter(Position = 0, ValueFromPipeline)]
        [AllowNull()]
        [object] $Value
    )
    process {
        if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
            return $null
        }
        if ($Value -is [datetime]) { return ([datetime]$Value).ToUniversalTime() }

        [datetime]$parsed = [datetime]::MinValue
        $styles = [System.Globalization.DateTimeStyles]::AdjustToUniversal -bor `
                  [System.Globalization.DateTimeStyles]::AssumeUniversal
        if ([datetime]::TryParse([string]$Value, [System.Globalization.CultureInfo]::InvariantCulture, $styles, [ref]$parsed)) {
            return $parsed
        }
        return $null
    }
}
