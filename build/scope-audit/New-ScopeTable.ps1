param(
    [string] $Inventory = "$PSScriptRoot\call-inventory-final.csv",
    [string] $OutFile = "$PSScriptRoot\scope-table.md"
)
$ErrorActionPreference = 'Stop'
Import-Module 'C:\dev\PSGraphKit\src\PSGraphKit\PSGraphKit.psd1' -Force
$map = & (Get-Module PSGraphKit) { $script:GkScopeMap }
$calls = Import-Csv $Inventory
$bt = [char]0x60   # backtick, kept out of the string literals below

$lines = foreach ($k in ($map.Keys | Sort-Object)) {
    $entry = $map[$k]
    $base = ($k -split ':')[0]

    $eps = @($calls | Where-Object Cmdlet -eq $base |
        ForEach-Object { "$bt$($_.Method) $($_.Path)$bt" } | Sort-Object -Unique) -join '<br>'
    if (-not $eps) { $eps = '_(no direct Graph call)_' }

    $groups = @($entry.Groups | ForEach-Object {
        $any = ($_.Any | ForEach-Object { "$bt$_$bt" }) -join ', '
        "**$($_.For)**: $any"
    }) -join '<br>'
    if (-not $groups) { $groups = '_(none — validates the session only)_' }

    $flags = @()
    if ($entry.DelegatedOnly) { $flags += 'delegated-only' }
    $flagText = if ($flags) { ' _(' + ($flags -join ', ') + ')_' } else { '' }

    "| $bt$k$bt$flagText | $eps | $groups |"
}

$header = @(
    '| Cmdlet | Graph calls | Capability groups (any one scope per group) |',
    '|---|---|---|'
)
Set-Content -Path $OutFile -Value (@($header) + @($lines)) -Encoding utf8
Write-Output "Wrote $($lines.Count) rows to $OutFile"
