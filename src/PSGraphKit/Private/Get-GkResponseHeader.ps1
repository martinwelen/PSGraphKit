function Get-GkResponseHeader {
    <#
    .SYNOPSIS
        Read a single response-header value case-insensitively from an Invoke-MgGraphRequest
        -ResponseHeadersVariable dictionary (values are typically string arrays).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Position = 0)] [AllowNull()] [object] $Headers,
        [Parameter(Position = 1, Mandatory)] [string] $Name
    )
    if ($null -eq $Headers) { return $null }
    foreach ($key in $Headers.Keys) {
        if ([string]::Equals([string]$key, $Name, [System.StringComparison]::OrdinalIgnoreCase)) {
            $val = $Headers[$key]
            if ($val -is [System.Array]) { return [string]@($val)[0] }
            return [string]$val
        }
    }
    return $null
}
