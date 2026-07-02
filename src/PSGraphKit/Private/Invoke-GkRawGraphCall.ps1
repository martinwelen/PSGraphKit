function Invoke-GkRawGraphCall {
    <#
    .SYNOPSIS
        Thin seam over Invoke-MgGraphRequest that normalizes a single HTTP call to
        { StatusCode, Headers, Body }. This is the ONE place the -StatusCodeVariable /
        -ResponseHeadersVariable mechanism lives, which keeps the retry/paging/error logic in
        Invoke-GkGraphRequest fully unit-testable by mocking this function.
    .DESCRIPTION
        The real cmdlet writes -StatusCodeVariable / -ResponseHeadersVariable into THIS
        function's scope, so $sc / $rh are populated after the call. -SkipHttpErrorCheck stops
        4xx/5xx from throwing so the caller can inspect status and headers itself.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [hashtable] $RequestParams
    )

    $sc = $null
    $rh = $null

    $p = @{} + $RequestParams
    $p['OutputType']              = 'HashTable'
    $p['SkipHttpErrorCheck']      = $true
    $p['StatusCodeVariable']      = 'sc'
    $p['ResponseHeadersVariable'] = 'rh'
    $p['ErrorAction']             = 'Stop'

    $body = Invoke-MgGraphRequest @p

    [pscustomobject]@{
        StatusCode = $sc
        Headers    = $rh
        Body       = $body
    }
}
