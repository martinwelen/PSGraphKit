# Merge the statically extracted call inventory with the hand-verified supplement.
#
# Rule: the supplement wins per cmdlet. A cmdlet listed in call-supplement.csv takes its calls
# ONLY from there, and its statically derived rows are discarded. That matters for cmdlets whose
# URI is assembled at runtime — Get-GkDeletedItem builds a type cast segment, so static analysis
# yields '/directory/deletedItems/{id}', which is a real Graph endpoint but not the one it calls.
param(
    [string] $Inventory = "$PSScriptRoot\call-inventory.csv",
    [string] $Supplement = "$PSScriptRoot\call-supplement.csv",
    [string] $OutFile = "$PSScriptRoot\call-inventory-final.csv"
)
$ErrorActionPreference = 'Stop'

$static = @(Import-Csv $Inventory)
$manual = @(Import-Csv $Supplement)

$unresolved = @($static | Where-Object Path -eq '<UNRESOLVED>')
$covered = @($manual.Cmdlet | Select-Object -Unique)

$merged = @(
    $static | Where-Object { $_.Path -ne '<UNRESOLVED>' -and $covered -notcontains $_.Cmdlet }
    $manual
) | Sort-Object Cmdlet, Method, Path -Unique

$merged | Export-Csv $OutFile -NoTypeInformation -Encoding utf8

Write-Output "Merged: $($merged.Count) calls across $(($merged.Cmdlet | Select-Object -Unique).Count) cmdlets"
Write-Output "Hand-verified cmdlets: $($covered.Count)"

# Anything still unresolved and NOT covered by the supplement is a genuine gap — the audit would
# silently under-report that cmdlet's surface.
$gaps = @($unresolved | Where-Object { $covered -notcontains $_.Cmdlet })
if ($gaps) {
    Write-Warning "Unresolved calls with no supplement entry — add them to call-supplement.csv:"
    $gaps | ForEach-Object { Write-Warning "  $($_.Cmdlet): $($_.Source)" }
}
else {
    Write-Output 'No unresolved calls outside the supplement.'
}
