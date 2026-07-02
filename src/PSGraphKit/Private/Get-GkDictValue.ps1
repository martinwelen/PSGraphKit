function Get-GkDictValue {
    <#
    .SYNOPSIS
        Safely read a key from a Graph response item (Invoke-GkGraphRequest returns items as
        nested hashtables). Returns $null when the dictionary or key is absent, so callers can
        navigate optional/nullable Graph properties without StrictMode errors.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)] [AllowNull()] [object] $Dictionary,
        [Parameter(Position = 1, Mandatory)] [string] $Key
    )
    if ($Dictionary -is [System.Collections.IDictionary] -and $Dictionary.Contains($Key)) {
        return $Dictionary[$Key]
    }
    return $null
}
